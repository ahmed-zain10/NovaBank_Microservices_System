# ⚙️ README — DevOps & Infrastructure

> توثيق البنية التحتية لـ NovaBank — بيئة التطوير المحلي (Docker Compose) والنشر على AWS.
>

---

## Stack التقني

| البيئة | الأداة | الدور |
|--------|--------|-------|
| **Local** | Docker 24+ | Containerization |
| **Local** | Docker Compose v2 | Orchestration |
| **Local** | Nginx alpine | Reverse proxy + static serving |
| **Local** | PostgreSQL 15-alpine | 4 قواعد بيانات مستقلة |
| **Local** | Python 3.12-slim | Runtime للـ services |
| **Cloud** | AWS ECS Fargate | تشغيل الـ containers |
| **Cloud** | AWS RDS PostgreSQL | قاعدة البيانات (schema isolation) |
| **Cloud** | AWS ALB | Load Balancer بديل Nginx |
| **Cloud** | AWS CloudFront + WAF | CDN + حماية |
| **Cloud** | Terraform 1.7+ | Infrastructure as Code |

---

## البيئة المحلية — Docker Compose

### الـ Services (11 container)

```
nginx                ← reverse proxy رئيسي :8080
frontend-customers   ← static SPA :3000
frontend-teller      ← static SPA :3001
api-gateway          ← :8000
auth-service         ← :8001  +  auth-db (PostgreSQL)
accounts-service     ← :8002  +  accounts-db (PostgreSQL)
transactions-service ← :8003  +  transactions-db (PostgreSQL)
notifications-service← :8004  +  notifications-db (PostgreSQL)
```

### الشبكة

```yaml
networks:
  nova-network:
    driver: bridge
```

جميع الـ containers على نفس الشبكة `nova-network`. التواصل بين الـ services يتم بالـ service name مباشرة:

```
http://auth-service:8001
http://accounts-service:8002
http://transactions-service:8003
http://notifications-service:8004
```

### الـ Volumes (بيانات دائمة)

```yaml
volumes:
  auth_data:           # بيانات auth-db
  accounts_data:       # بيانات accounts-db
  transactions_data:   # بيانات transactions-db
  notifications_data:  # بيانات notifications-db
```

البيانات تبقى محفوظة بعد `docker compose down`. تُحذف فقط بـ:

```bash
docker compose down -v   # حذف الـ volumes أيضاً (reset كامل)
```

---

## Health Checks

كل قاعدة بيانات لها healthcheck:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U nova -d auth_db"]
  interval: 5s
  timeout: 5s
  retries: 10
```

الـ services تنتظر الـ DB:

```yaml
depends_on:
  auth-db:
    condition: service_healthy
```

وكل service فيها retry loop داخلي عند الـ startup:

```python
for i in range(20):
    try:
        init_db()
        return
    except Exception as e:
        log.warning(f"DB not ready ({i+1}/20): {e}")
        time.sleep(3)
raise RuntimeError("DB failed after 20 retries")
```

---

## Nginx — الـ Reverse Proxy (Local)

**الملف:** `infrastructure/nginx/nginx.conf`

```nginx
upstream api_gateway {
    server api-gateway:8000;
}

server {
    listen 80;

    location /api/ {
        proxy_pass http://api_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

> **في الـ production على AWS:** Nginx استُبدل بـ **AWS ALB** الذي يقوم بنفس مهمة الـ routing مع إضافة SSL termination وhealth checks وauto scaling. انظر `INFRASTRUCTURE-on-AWS.md` → Section 5.

---

## قواعد البيانات — الفصل الكامل

### Local (Docker Compose)

كل service لها container PostgreSQL مستقل:

| Service | Host | DB Name | User |
|---------|------|---------|------|
| auth | `auth-db:5432` | `auth_db` | nova |
| accounts | `accounts-db:5432` | `accounts_db` | nova |
| transactions | `transactions-db:5432` | `transactions_db` | nova |
| notifications | `notifications-db:5432` | `notifications_db` | nova |

### Production (AWS RDS)

instance PostgreSQL واحدة (`novabank-dev-rds`) بـ **4 schemas معزولة**. الـ schema init بيتعمل عن طريق **AWS Lambda function** (`novabank-dev-db-init`) بيتشغل بعد الـ deploy مباشرةً.

**الـ Lambda بتعمل:**
1. تتصل بـ RDS بـ master credentials من Secrets Manager
2. تخلق كل schema لو مش موجودة: `CREATE SCHEMA IF NOT EXISTS`
3. تخلق user مخصص لكل schema بـ password من Secrets Manager
4. تعطي كل user صلاحيات على schema بتاعته بس

| Schema | User | Secret ARN |
|--------|------|-----------|
| `auth` | `auth_user` | `novabank/dev/rds/auth` |
| `accounts` | `accounts_user` | `novabank/dev/rds/accounts` |
| `transactions` | `transactions_user` | `novabank/dev/rds/transactions` |
| `notifications` | `notifications_user` | `novabank/dev/rds/notifications` |

**عزل الصلاحيات:**
```sql
-- كل user شايف schema بتاعته بس
GRANT USAGE ON SCHEMA auth TO auth_user;
GRANT CREATE ON SCHEMA auth TO auth_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth GRANT ALL ON TABLES TO auth_user;
ALTER USER auth_user SET search_path TO auth, public;
```

انظر `INFRASTRUCTURE-on-AWS.md` → Section 8.

### init_db() — إنشاء الجداول تلقائياً

كل service تُنشئ جداولها عند أول تشغيل باستخدام `CREATE TABLE IF NOT EXISTS`. لا يوجد migration tool — النظام self-initializing.

**مبدأ أساسي:** لا توجد أي service تقرأ مباشرة من قاعدة بيانات service أخرى. كل تبادل بيانات يتم عبر HTTP API.

---

## Dockerfiles

### Backend Services

```dockerfile
FROM python:3.12-slim

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER appuser

ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

> **entrypoint.sh:** في الـ production، هذا الملف يقرأ credentials من AWS Secrets Manager ويبني `DATABASE_URL` قبل بدء الـ application. انظر `DEPLOY_AND_DESTROY.md` → Step 4.

### Frontend Services

```dockerfile
FROM nginx:1.27-alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## Environment Variables

### Local (docker-compose)

```env
# API Gateway
AUTH_URL=http://auth-service:8001
ACCOUNTS_URL=http://accounts-service:8002
TRANSACTIONS_URL=http://transactions-service:8003
NOTIFICATIONS_URL=http://notifications-service:8004
JWT_SECRET=change-this-in-production

# Auth Service
DATABASE_URL=postgresql://nova:secret@auth-db:5432/auth_db
ACCOUNTS_URL=http://accounts-service:8002

# Transactions Service
DATABASE_URL=postgresql://nova:secret@transactions-db:5432/transactions_db
ACCOUNTS_URL=http://accounts-service:8002
NOTIFICATIONS_URL=http://notifications-service:8004
SQS_QUEUE_URL=http://... (AWS only)
```

> **في الـ production على AWS:** لا توجد أي secrets في environment variables. كل الـ credentials محفوظة في **AWS Secrets Manager** ويتم حقنها وقت التشغيل عبر `entrypoint.sh`. انظر `INFRASTRUCTURE-on-AWS.md` → Section 9.

---

## تشغيل المشروع (Local)

```bash
# أول تشغيل (build كامل)
docker compose up --build

# تشغيل عادي
docker compose up -d

# إيقاف مع حفظ البيانات
docker compose down

# إيقاف مع حذف البيانات (reset كامل)
docker compose down -v

# logs
docker compose logs -f
docker compose logs -f transactions-service

# Health check شامل
curl http://localhost:8000/ready
# {"status":"ready","services":{"auth":"ok","accounts":"ok","transactions":"ok","notifications":"ok"}}
```

---

---

## الفرق بين Local وProduction

| الجانب | Local (Docker Compose) | Production (AWS) |
|--------|----------------------|-----------------|
| Routing | Nginx container | AWS ALB |
| Database | 4 containers PostgreSQL | RDS واحدة + 4 schemas |
| Secrets | `.env` file | AWS Secrets Manager |
| Scaling | يدوي | Auto Scaling تلقائي |
| SSL | لا يوجد | CloudFront + ACM |
| Monitoring | `docker compose logs` | CloudWatch Logs |
| HA | لا يوجد | Multi-AZ (prod) |

---

## Jenkins CI/CD Pipelines

المشروع عنده **3 pipelines** في Jenkins بتتحكم في كل دورة الـ deploy:

| Pipeline | الملف | الغرض | متى يشتغل |
|----------|-------|--------|-----------|
| **Full Deploy** | `Jenkinsfiles/Jenkinsfile.deploy` | ينشئ كل الـ infrastructure من الصفر | يدوي |
| **CI/CD** | `Jenkinsfiles/Jenkinsfile.cicd` | يبني ويعمل deploy للـ services اللي اتغيرت بس | تلقائي عند كل push على main |
| **Destroy** | `Jenkinsfiles/Jenkinsfile.destroy` | يمسح كل الـ infrastructure | يدوي مع تأكيد |

### Jenkins Credentials المطلوبة

| Credential ID | النوع | المحتوى |
|--------------|-------|---------|
| `aws-creds` | AWS Credentials | AWS Access Key ID + Secret Access Key |
| `terraform-tfvars-dev` | Secret File | ملف `terraform.tfvars` بتاع الـ dev environment |

### Pipeline 1: Full Deploy
بيمشي على 15 stage بالترتيب:
`Install Dependencies` → `Checkout` → `Bootstrap State` → `Build Lambda` → `Terraform Init` → `Import Secrets` → `Terraform Plan` → `Terraform Apply` → `Deploy Lambda` → `ECR Login` → `Build & Push Images` → `Init Database` → `Deploy ECS Services` → `Health Check`

### Pipeline 2: CI/CD (Webhook)
بيشتغل تلقائياً على كل push على `main`. بيكتشف الـ services اللي اتغيرت بـ `git diff` وبيبني ويعمل deploy ليها بس — مش كل الـ 7 services.

### Pipeline 3: Destroy
بيمسح كل الـ infrastructure مع manual approval. بيمشي على:
`Show Resources` → `Manual Approval` → `Stop ECS` → `Clear ECR` → `Terraform Init` → `Terraform Destroy` → `Delete State Bucket` → `Delete Lock Table` → `Verify Destruction`

للتوثيق التفصيلي لكل stage: [`PIPELINES_README.md`](./PIPELINES_README.md)

---

## AWS Infrastructure — Architecture

## Architecture Overview

```
Internet
    │
    ▼
CloudFront (2 distributions)
├── customers.novabank.com  →  WAF (public + rate limit + OWASP)
└── teller.novabank.com     →  WAF (IP allowlist + OWASP)
    │
    ▼
Application Load Balancer (HTTPS only)
├── /api/*      →  ECS: api-gateway (port 8000)
├── /teller/*   →  ECS: frontend-teller (port 80)
└── /*          →  ECS: frontend-customers (port 80)
    │
    ├── ECS Fargate (private subnets, Service Discovery)
    │   ├── api-gateway           :8000
    │   ├── auth-service          :8001
    │   ├── accounts-service      :8002
    │   ├── transactions-service  :8003
    │   └── notifications-service :8004
    │
    └── RDS PostgreSQL (private subnets, Multi-AZ in prod)
        ├── schema: auth          (user: auth_user)
        ├── schema: accounts      (user: accounts_user)
        ├── schema: transactions  (user: transactions_user)
        └── schema: notifications (user: notifications_user)
```

## Directory Structure

```
terraform/
├── modules/
│   ├── vpc/             VPC, subnets, NAT GWs, Flow Logs
│   ├── security-groups/ ALB/ECS/RDS SGs, VPC Endpoints
│   ├── secrets/         Secrets Manager (DB creds, JWT)
│   ├── rds/             PostgreSQL + schema init Lambda
│   ├── ecr/             Container registries (7 repos)
│   ├── alb/             Application Load Balancer
│   ├── ecs/             Fargate cluster + 7 services
│   ├── waf/             WAFv2 (customers + teller)
│   └── cloudfront/      2 CloudFront distributions
│
├── envs/
│   ├── dev/             Dev deployment (small instances, SPOT)
│   └── prod/            Prod deployment (HA, Multi-AZ, on-demand)
│
└── scripts/
    ├── bootstrap_state.sh   Create S3+DynamoDB for remote state
    ├── push_images.sh       Build & push Docker images to ECR
    └── entrypoint.sh        Container entrypoint (secrets → env vars)
```

---

## Step-by-Step Deployment

### Prerequisites

```bash
# Install required tools
brew install terraform awscli docker

# Verify
terraform version   # >= 1.7.0
aws --version
docker --version

# Configure AWS credentials
aws configure
# OR use AWS SSO / environment variables
```

### Step 1 — Bootstrap Remote State (run once per env)

```bash
chmod +x scripts/bootstrap_state.sh

# For dev
./scripts/bootstrap_state.sh dev eu-west-1

# For prod
./scripts/bootstrap_state.sh prod eu-west-1
```

This creates:
- S3 bucket `novabank-terraform-state-<env>` (versioned, encrypted, private)
- DynamoDB table `novabank-terraform-locks-<env>` (for state locking)

### Step 2 — Build the DB Init Lambda

```bash
cd modules/rds
chmod +x build_lambda.sh
./build_lambda.sh
# Creates: modules/rds/db_init_lambda.zip
cd ../..
```

### Step 3 — Fill in Your Values

Edit `envs/dev/terraform.tfvars`:

```hcl
# Your domain (must exist in Route53)
hosted_zone_name  = "novabank.yourdomain.com"
customer_domain   = "app-dev.novabank.yourdomain.com"
teller_domain     = "teller-dev.novabank.yourdomain.com"

# ACM certificates (must be validated)
# One in your main region (for ALB)
acm_certificate_arn = "arn:aws:acm:eu-west-1:ACCOUNT:certificate/CERT_ID"
# One in us-east-1 (for CloudFront) — even if your region is different
acm_certificate_arn_us_east_1 = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"

# Your office IP(s) that can access the teller portal
teller_allowed_ips = ["YOUR.OFFICE.IP.ADDRESS/32"]

# ALB account ID for your region:
# eu-west-1:    156460612806
# us-east-1:    127311923021
# eu-central-1: 054676820928
alb_account_id = "156460612806"
```

### Step 4 — Initialize and Deploy

```bash
cd envs/dev

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Terraform will create ~80 resources. Estimated time: 15-20 minutes (RDS takes longest).

### Step 5 — Build & Push Docker Images

```bash
# From project root
cd ../../  # back to nova_final directory

# Get your ECR URLs from terraform output
terraform -chdir=terraform/envs/dev output ecr_repositories

# Build and push all 7 images
chmod +x terraform/scripts/push_images.sh
./terraform/scripts/push_images.sh dev eu-west-1 YOUR_ACCOUNT_ID v1.0.0
```

### Step 6 — Update Dockerfiles to Use Entrypoint

Copy the entrypoint script to each service:

```bash
cp terraform/scripts/entrypoint.sh services/auth-service/
cp terraform/scripts/entrypoint.sh services/accounts-service/
# ... repeat for all services
```

Add to each backend Dockerfile:
```dockerfile
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

### Step 7 — Initialize Database Schemas

```bash
aws lambda invoke \
  --function-name novabank-dev-db-init \
  --region eu-west-1 \
  /tmp/db-init-output.json

cat /tmp/db-init-output.json
# Should show: {"statusCode": 200, "body": "DB init complete"}
```

### Step 8 — Deploy Updated Images

```bash
# Push with specific tag
./terraform/scripts/push_images.sh dev eu-west-1 YOUR_ACCOUNT_ID v1.0.0

# Update ECS services to use new tag
cd terraform/envs/dev
terraform apply -var="image_tag=v1.0.0" -var-file=terraform.tfvars
```

---

## Key Security Decisions

| Concern | Solution |
|---------|----------|
| No secrets in code | All credentials in AWS Secrets Manager, injected at runtime |
| Teller access | WAF IP allowlist + CloudFront geo-restriction (Egypt only) |
| Database isolation | Separate PostgreSQL schemas + dedicated DB users per service |
| No direct DB access | RDS in private subnet, no public IP, SG allows ECS only |
| Traffic integrity | CloudFront → ALB uses secret header, blocks direct ALB hits |
| Encryption at rest | KMS encrypts RDS, ECR, Secrets Manager |
| Encryption in transit | TLS 1.2+ enforced at CloudFront and ALB |
| Container security | ECR image scanning on push |
| State security | Remote state in S3 (encrypted) + DynamoDB locking |

---

## Operational Commands

```bash
# View logs for a service
aws logs tail /novabank/dev/api-gateway --follow
aws logs tail /novabank/dev/auth-service --follow

# Force ECS service redeploy (after pushing new image)
aws ecs update-service \
  --cluster novabank-dev-cluster \
  --service novabank-dev-api-gateway \
  --force-new-deployment \
  --region eu-west-1

# Redeploy ALL services at once
for svc in auth-service accounts-service transactions-service notifications-service api-gateway frontend-customers frontend-teller; do
  aws ecs update-service \
    --cluster novabank-dev-cluster \
    --service "novabank-dev-${svc}" \
    --force-new-deployment \
    --region eu-west-1 \
    --query 'service.serviceName' \
    --output text
done

# Check service health
aws ecs describe-services \
  --cluster novabank-dev-cluster \
  --services novabank-dev-api-gateway \
  --region eu-west-1 \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# View RDS performance insights
aws pi get-resource-metrics \
  --service-type RDS \
  --identifier db:novabank-dev-rds \
  --metric-queries '[{"Metric":"db.load.avg"}]' \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period-in-seconds 300

# Update teller allowed IPs without full apply
terraform apply \
  -var="teller_allowed_ips=[\"NEW.IP.ADDRESS/32\"]" \
  -var-file=terraform.tfvars \
  -target=module.waf.aws_wafv2_ip_set.teller_allowed
```

---

## Environment Differences

| Setting | Dev | Prod |
|---------|-----|------|
| RDS Instance | db.t3.micro | db.t3.medium |
| RDS Multi-AZ | No | Yes |
| RDS Backup | 3 days | 14 days |
| RDS Deletion Protection | No | Yes |
| ECS Capacity | FARGATE_SPOT | FARGATE |
| ECS Replicas | 1 | 2 |
| AZs | 2 | 3 |
| CloudFront Price Class | PriceClass_100 | PriceClass_All |
| Log Retention | 14 days | 90 days |

---

---

## Terraform Versions

```hcl
terraform  >= 1.7.0
aws        ~> 5.50
random     ~> 3.6
```

---

## Deploy & Destroy (Manual)

> ⚠️ الطريقة الأساسية هي Jenkins Pipelines — استخدم الأوامر دي بس لو مش عندك Jenkins.

## 🚀 Deploy

```bash
# 1. Bootstrap (مرة واحدة بس)
cd terraform/scripts && ./bootstrap_state.sh dev us-east-1

# 2. Build Lambda zip (مرة واحدة بس)
cd terraform/modules/rds && ./build_lambda.sh

# 3. Init + Apply
cd terraform/envs/dev
terraform init
terraform apply -var-file=terraform.tfvars

# 4. Push Docker Images
cd ../../.. && ./terraform/scripts/push_images.sh dev us-east-1 816709079108 v1.0.0

# 5. Init DB
aws lambda invoke --function-name novabank-dev-db-init --region us-east-1 /tmp/out.json
cat /tmp/out.json

# 6. Verify services
aws ecs describe-services \
  --cluster novabank-dev-cluster \
  --services novabank-dev-api-gateway novabank-dev-auth-service \
             novabank-dev-accounts-service novabank-dev-transactions-service \
             novabank-dev-notifications-service novabank-dev-frontend-customers \
             novabank-dev-frontend-teller \
  --region us-east-1 \
  --query 'services[*].{Name:serviceName,Running:runningCount,Desired:desiredCount}' \
  --output table
```

---

## 🗑️ Destroy

```bash
# 1. افرغ ECR (لازم قبل destroy)
for repo in accounts-service api-gateway auth-service transactions-service \
            notifications-service frontend-customers frontend-teller; do
  IMAGE_IDS=$(aws ecr list-images --repository-name "novabank/dev/${repo}" \
    --region us-east-1 --query 'imageIds[*]' --output json)
  [ "$IMAGE_IDS" = "[]" ] && continue
  aws ecr batch-delete-image --repository-name "novabank/dev/${repo}" \
    --image-ids "$IMAGE_IDS" --region us-east-1
done

# 2. Terraform Destroy
cd terraform/envs/dev
terraform destroy -var-file=terraform.tfvars
# لو الـ DynamoDB اتمسحت يدوياً:
# terraform destroy -var-file=terraform.tfvars -lock=false

# 3. امسح S3 State Bucket
BUCKET="novabank-terraform-state-dev"
for TYPE in Versions DeleteMarkers; do
  aws s3api list-object-versions --bucket "$BUCKET" --region us-east-1 \
    --query "${TYPE}[].{Key:Key,VersionId:VersionId}" --output json | \
    python3 -c "
import sys,json,subprocess
items=json.load(sys.stdin)
if not items: sys.exit(0)
subprocess.run(['aws','s3api','delete-objects','--bucket','$BUCKET',
  '--delete',json.dumps({'Objects':items,'Quiet':True}),'--region','us-east-1'])
print(f'Deleted {len(items)} ${TYPE}')
"
done
aws s3api delete-bucket --bucket "$BUCKET" --region us-east-1 && echo "Bucket deleted"

# 4. امسح DynamoDB
aws dynamodb delete-table --table-name novabank-terraform-locks-dev --region us-east-1
```

> ⚠️ لو اضطريت تعمل `-lock=false` — الـ terraform بيكتب state جديد في الـ bucket.
> افحص بـ `aws s3api list-object-versions --bucket $BUCKET --region us-east-1 --output json`
> وامسح أي version فاضل يدوياً قبل ما تمسح الـ bucket.