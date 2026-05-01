<div align="center">

# 🏦 NovaBank — البنك الرقمي المتكامل

<img src="https://img.shields.io/badge/Architecture-Microservices-0A0F1E?style=for-the-badge&logo=docker&logoColor=C9A84C"/>
<img src="https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white"/>
<img src="https://img.shields.io/badge/Database-PostgreSQL-336791?style=for-the-badge&logo=postgresql&logoColor=white"/>
<img src="https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white"/>
<img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white"/>
<img src="https://img.shields.io/badge/Auth-JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white"/>
<img src="https://img.shields.io/badge/Frontend-HTML%2FCSS%2FJS-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black"/>
<img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white"/>
<img src="https://img.shields.io/badge/CI%2FCD-Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white"/>

<br/><br/>

> **نظام بنكي رقمي كامل مبني بمعمارية Microservices — يشمل بوابة API، خدمات مستقلة، قواعد بيانات معزولة، لوحة عملاء ولوحة موظفين، منشور على AWS ECS Fargate بـ Terraform.**

</div>

---

## ما هو NovaBank؟

NovaBank نظام بنكي رقمي متكامل يجسّد مفهوم **Microservices Architecture** من الصفر. كل خدمة تعيش في container مستقل، لها قاعدة بياناتها الخاصة، وتتواصل مع بقية الخدمات عبر HTTP. المشروع يدعم بيئتين: **local** عبر Docker Compose، و**production** على AWS.

---

## التقنيات المستخدمة

| الطبقة | التقنيات |
|--------|---------|
| **Backend** | Python 3.12 · FastAPI · psycopg2 · httpx · python-jose · bcrypt |
| **Database** | PostgreSQL 15 — قاعدة بيانات مستقلة لكل service |
| **Frontend** | HTML5 · CSS3 · Vanilla JavaScript (SPA — بدون framework) |
| **Infrastructure (Local)** | Docker · Docker Compose · Nginx |
| **Infrastructure (Cloud)** | AWS ECS Fargate · RDS · ALB · CloudFront · WAF · Route53 |
| **IaC** | Terraform 1.7+ — Remote state على S3 + DynamoDB |
| **CI/CD** | Jenkins · GitHub Webhooks — 3 pipelines (Deploy · CI/CD · Destroy) |
| **Notifications** | AWS SQS · AWS SNS (SMS) · AWS SES (Email) |
| **Security** | JWT HS256 · bcrypt · Rate Limiting · RBAC · AWS WAFv2 |

---

## معمارية النظام

### Local (Docker Compose)

```
                        ┌────────────────────────────────────┐
                        │        CLIENT BROWSER              │
                        │  frontend-customers   frontend-teller│
                        │       :3000                :3001    │
                        └─────────────┬──────────────────────┘
                                      │
                        ┌─────────────▼──────────────────────┐
                        │          NGINX :8080               │
                        │      Reverse Proxy + Routing        │
                        └─────────────┬──────────────────────┘
                                      │
                        ┌─────────────▼──────────────────────┐
                        │         API GATEWAY :8000           │
                        │    JWT · Rate Limit · RBAC          │
                        └──┬──────────┬──────────┬───────────┘
                           │          │          │          │
                      auth-svc  accounts-svc  txn-svc  notif-svc
                       :8001      :8002        :8003     :8004
                         │          │            │          │
                      auth-db  accounts-db   txn-db   notif-db
```

### Production (AWS)

```
User
 │
 ▼
Route53
 │
 ▼
CloudFront (2 distributions)
├── app-dev.novabank-eg.com   →  WAF (OWASP + rate limit)
└── teller-dev.novabank-eg.com →  WAF (IP allowlist + OWASP)
 │
 ▼
Application Load Balancer (HTTPS only)
├── /api/*    →  ECS: api-gateway        :8000
├── /teller/* →  ECS: frontend-teller   :80
└── /*        →  ECS: frontend-customers :80
 │
 ├── ECS Fargate (private subnets — Service Discovery)
 │   ├── api-gateway           :8000  (JWT · Rate Limit · RBAC)
 │   ├── auth-service          :8001
 │   ├── accounts-service      :8002
 │   ├── transactions-service  :8003 ──► SQS
 │   └── notifications-service :8004 ◄── SQS ──► SNS (SMS) · SES (Email)
 │
 └── RDS PostgreSQL (private subnets)
     ├── schema: auth          (user: auth_user)
     ├── schema: accounts      (user: accounts_user)
     ├── schema: transactions  (user: transactions_user)
     └── schema: notifications (user: notifications_user)
```

---

## الفيتشرز الرئيسية

### بوابة العملاء
- تسجيل حساب جديد / تسجيل دخول
- لوحة تحكم بالرصيد والمعاملات الأخيرة
- تحويل أموال · دفع فواتير · صرف عملات
- إدارة البطاقات البنكية · أهداف الادخار · قروض · محفظة استثمارية
- إشعارات فورية (in-app + SMS + Email)

### بوابة الخزينة (Teller)
- تسجيل دخول الموظفين برقم الموظف
- عرض جميع الحسابات والبحث والتصفية
- إيداع · سحب · تحويل · تجميد/فك تجميد الحسابات
- سجل عمليات اليوم · سجل مراجعة كامل (audit log)
- لوحة مراقبة للمدراء والـ supervisors

### نظام الأمان
- JWT مع RBAC: `customer / teller / supervisor / admin`
- Rate limiting على login endpoints
- bcrypt password hashing
- AWS WAFv2: OWASP rules + IP allowlist للتيلر

---

## هيكل المشروع

```
novabank/
├── nova_final/                        # Local development
│   ├── docker-compose.yml
│   ├── infrastructure/nginx/
│   └── services/
│       ├── api-gateway/
│       ├── auth-service/
│       ├── accounts-service/
│       ├── transactions-service/
│       ├── notifications-service/
│       ├── frontend-customers/
│       └── frontend-teller/
│
├── Jenkinsfiles/                      # Jenkins CI/CD Pipelines
│   ├── Jenkinsfile.deploy             # Full deploy من الصفر
│   ├── Jenkinsfile.cicd               # Webhook — deploy الـ services اللي اتغيرت
│   └── Jenkinsfile.destroy            # مسح كل الـ infrastructure
│
└── terraform/                         # AWS production infrastructure
    ├── README.md                      # توثيق الـ Terraform modules والـ deployment
    ├── modules/
    │   ├── vpc/
    │   ├── security-groups/
    │   ├── secrets/
    │   ├── rds/
    │   ├── ecr/
    │   ├── alb/
    │   ├── ecs/
    │   ├── waf/
    │   ├── cloudfront/
    │   └── messaging/           # SQS + SNS
    └── envs/
        ├── dev/
        └── prod/
```

---

## تشغيل المشروع — Local

### المتطلبات
- Docker v20.10+
- Docker Compose v2.0+

### تشغيل بأمر واحد

```bash
git clone https://github.com/your-username/novabank.git
cd novabank/nova_final
docker compose up --build
```

### الروابط

| الخدمة | الرابط |
|--------|--------|
| Customer Portal | http://localhost:3000 |
| Teller System | http://localhost:3001 |
| API Gateway | http://localhost:8000 |
| Health Check | http://localhost:8000/ready |

### بيانات الدخول التجريبية

**عملاء:**

| الاسم | الإيميل | كلمة المرور |
|-------|---------|------------|
| أحمد محمد | demo@novabank.eg | demo123 |
| نور علي | nour.ali@gmail.com | nour123 |
| تامر حسن | tamer.h@outlook.com | tamer456 |

**موظفون:**

| اسم المستخدم | كلمة المرور | الدور |
|------------|------------|-------|
| m.elsayed | teller123 | Teller |
| s.ahmed | teller456 | Supervisor |
| k.abdallah | admin789 | Admin |

---

## نشر المشروع — AWS Production

> النشر بيتم عن طريق **Jenkins** — انظر [`README.devops.md`](./README.devops.md) للتفصيل الكامل.

الخطوات باختصار عبر Jenkins:

```
1. شغّل pipeline: Jenkinsfile.deploy
2. حدد IMAGE_TAG (مثال: v1.0.0)
3. Jenkins بيعمل كل حاجة تلقائياً (~20 دقيقة)
```

أو يدوياً:

```bash
# 1. Bootstrap remote state
./terraform/scripts/bootstrap_state.sh dev us-east-1

# 2. Deploy infrastructure (~15 دقيقة)
cd terraform/envs/dev
terraform init && terraform apply -var-file=terraform.tfvars

# 3. Push Docker images
./terraform/scripts/push_images.sh dev us-east-1 YOUR_ACCOUNT_ID v1.0.0

# 4. Initialize database schemas
aws lambda invoke --function-name novabank-dev-db-init --region us-east-1 /tmp/out.json
```

**Production URLs:**
- Customer Portal: `https://novabank-eg.com`
- Teller Portal: `https://teller.novabank-eg.com` *(IP-restricted)*

---

## نظام الصلاحيات (RBAC)

```
customer    → قراءة وعمليات على حسابه فقط
teller      → عمليات على حسابات العملاء + تقارير
supervisor  → صلاحيات teller + إدارة الموظفين
admin       → صلاحيات كاملة على النظام
```

---

## API Endpoints الرئيسية

<details>
<summary>🔑 Auth</summary>

```http
POST /api/auth/login
POST /api/auth/login-employee
POST /api/auth/register
POST /api/auth/change-password
```
</details>

<details>
<summary>💰 Accounts</summary>

```http
GET  /api/accounts/me
GET  /api/accounts/{id}/cards
POST /api/accounts/{id}/cards
GET  /api/accounts/{id}/goals
POST /api/accounts/{id}/goals
GET  /api/accounts/{id}/loans
POST /api/accounts/{id}/loans
GET  /api/accounts/{id}/portfolio
POST /api/accounts/{id}/portfolio
```
</details>

<details>
<summary>💸 Transactions</summary>

```http
POST /api/transactions/deposit
POST /api/transactions/withdraw
POST /api/transactions/transfer
POST /api/transactions/pay-bill
POST /api/transactions/exchange
GET  /api/transactions/rates
GET  /api/transactions/{account_id}
```
</details>

<details>
<summary>🔔 Notifications</summary>

```http
GET /api/notifications/{user_id}
PUT /api/notifications/{user_id}/read/{id}
PUT /api/notifications/{user_id}/read-all
```
</details>

---

## العملات المدعومة

| العملة | الرمز | المعدل (base: EGP) |
|--------|-------|-------------------|
| جنيه مصري | EGP | 1.0 |
| دولار أمريكي | USD | 0.0204 |
| يورو | EUR | 0.0188 |
| جنيه إسترليني | GBP | 0.016 |
| ريال سعودي | SAR | 0.0765 |
| درهم إماراتي | AED | 0.0749 |
| دينار كويتي | KWD | 0.00626 |

---

## التوثيق التقني

| الملف | المحتوى |
|-------|---------|
| [`README.backend.md`](./README.backend.md) | المعمارية · الـ services · الـ endpoints · المشاكل والحلول |
| [`README.frontend.md`](./README.frontend.md) | الـ SPA · تدفق البيانات · الصفحات · الـ UI |
| [`README.devops.md`](./README.devops.md) | Docker Compose · Nginx · قواعد البيانات · Jenkins Pipelines · AWS Infrastructure |
| [`INFRASTRUCTURE-on-AWS.md`](./INFRASTRUCTURE-on-AWS.md) | توثيق كل AWS resource بالتفصيل |
| [`terraform/README.md`](./terraform/README.md) | Terraform modules · directory structure · deployment steps |

---

<div align="center">

**صُنع بـ ❤️ و ☕ — NovaBank**

*Built with FastAPI · PostgreSQL · Docker · AWS · Terraform*

</div>
