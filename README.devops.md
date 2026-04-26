# ⚙️ README — DevOps & Infrastructure

> توثيق البنية التحتية لـ NovaBank — بيئة التطوير المحلي (Docker Compose) والنشر على AWS.
>
> **للنشر على AWS:** انظر [`DEPLOYMENT.md`](./DEPLOYMENT.md) و [`INFRASTRUCTURE.md`](./INFRASTRUCTURE.md)

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

> **في الـ production على AWS:** Nginx استُبدل بـ **AWS ALB** الذي يقوم بنفس مهمة الـ routing مع إضافة SSL termination وhealth checks وauto scaling. انظر `INFRASTRUCTURE.md` → Section 5.

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

instance PostgreSQL واحدة بـ **4 schemas معزولة** — كل service لها user خاص بصلاحيات محدودة على schema بتاعتها فقط. انظر `INFRASTRUCTURE.md` → Section 8.

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

> **entrypoint.sh:** في الـ production، هذا الملف يقرأ credentials من AWS Secrets Manager ويبني `DATABASE_URL` قبل بدء الـ application. انظر `DEPLOYMENT.md` → Step 4.

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

> **في الـ production على AWS:** لا توجد أي secrets في environment variables. كل الـ credentials محفوظة في **AWS Secrets Manager** ويتم حقنها وقت التشغيل عبر `entrypoint.sh`. انظر `INFRASTRUCTURE.md` → Section 9.

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

## المشاكل التي واجهناها

### 🔴 Cross-DB JOIN في transactions-service
**المشكلة:** الكود كان يحاول `LEFT JOIN accounts` من `transactions-db` — مستحيل في Microservices.

**الحل:** حذف الـ JOIN. كل service تقرأ فقط من قاعدة بياناتها. إذا احتجنا بيانات من service أخرى نطلبها عبر HTTP.

### 🟡 Race Condition عند Startup
**المشكلة:** الـ services تبدأ قبل جاهزية الـ DB رغم الـ healthcheck.

**الحل:** `condition: service_healthy` في `depends_on` + retry loop داخل الـ service.

### 🟡 Lambda Timeout في VPC (AWS فقط)
**المشكلة:** Lambda بتاعة DB init كانت بتاخد +14 دقيقة لأنها كانت بتستخدم RDS Security Group بدل security group خاص بيها.

**الحل:** Security Group منفصل للـ Lambda مع outbound rules صحيحة للـ RDS والـ VPC endpoints.

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

للتوثيق الكامل للبنية التحتية على AWS:
- **النشر خطوة بخطوة:** [`DEPLOYMENT.md`](./DEPLOYMENT.md)
- **توثيق كل AWS resource:** [`INFRASTRUCTURE.md`](./INFRASTRUCTURE.md)
