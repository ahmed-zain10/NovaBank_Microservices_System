# ⚙️ README — DevOps & Infrastructure

> توثيق البنية التحتية لـ NovaBank — Docker، Compose، Nginx، الشبكات، قواعد البيانات، والـ health checks.

---

## Stack التقني

| الأداة | الإصدار | الدور |
|--------|---------|-------|
| Docker | 24+ | containerization |
| Docker Compose | v2 | orchestration محلي |
| Nginx | alpine | reverse proxy + static serving |
| PostgreSQL | 15-alpine | قاعدة البيانات (× 4 instances) |
| Python | 3.11-slim | runtime للـ services |

---

## هيكل docker-compose.yml

### الـ Services (11 container)

```
nginx              ← reverse proxy رئيسي :8080
frontend-customers ← static SPA :3000
frontend-teller    ← static SPA :3001
api-gateway        ← gateway :8000
auth-service       ← :8001
auth-db            ← PostgreSQL
accounts-service   ← :8002
accounts-db        ← PostgreSQL
transactions-service ← :8003
transactions-db    ← PostgreSQL
notifications-service ← :8004
notifications-db   ← PostgreSQL
```

### الشبكة
```yaml
networks:
  nova-network:
    driver: bridge
```
جميع الـ containers على نفس الشبكة `nova-network` — يتواصلون بالـ service name مباشرة:
- `http://auth-service:8001`
- `http://accounts-service:8002`
- `http://transactions-service:8003`
- `http://notifications-service:8004`

### الـ Volumes (بيانات دائمة)
```yaml
volumes:
  auth_data:          # /var/lib/postgresql/data في auth-db
  accounts_data:      # /var/lib/postgresql/data في accounts-db
  transactions_data:  # /var/lib/postgresql/data في transactions-db
  notifications_data: # /var/lib/postgresql/data في notifications-db
```
البيانات تبقى محفوظة حتى بعد `docker compose down` — تُحذف فقط بـ `docker compose down -v`.

---

## Health Checks

كل قاعدة بيانات عندها healthcheck:
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U nova -d auth_db"]
  interval: 5s
  timeout: 5s
  retries: 10
```

الـ services تعتمد على `condition: service_healthy`:
```yaml
depends_on:
  auth-db:
    condition: service_healthy
```

وداخل كل service، retry loop عند الـ startup:
```python
for i in range(20):
    try:
        init_db()
        log.info("DB ready")
        return
    except Exception as e:
        log.warning(f"DB not ready ({i+1}/20): {e}")
        time.sleep(3)
raise RuntimeError("DB failed after 20 retries")
```

---

## Nginx — إعداد الـ Reverse Proxy

**الملف:** `infrastructure/nginx/nginx.conf`

```nginx
upstream api_gateway {
    server api-gateway:8000;
}

server {
    listen 80;

    # API — كل الطلبات /api/* تروح للـ gateway
    location /api/ {
        proxy_pass http://api_gateway;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

الـ frontends يخدمون مباشرة على منافذهم (:3000, :3001) بدون المرور بـ Nginx.

---

## قواعد البيانات — الفصل الكامل

كل service لها credentials مستقلة:

| Service | Host | DB Name | User |
|---------|------|---------|------|
| auth | `auth-db:5432` | `auth_db` | nova |
| accounts | `accounts-db:5432` | `accounts_db` | nova |
| transactions | `transactions-db:5432` | `transactions_db` | nova |
| notifications | `notifications-db:5432` | `notifications_db` | nova |

**مبدأ أساسي:** لا يوجد أي service يقرأ مباشرة من قاعدة بيانات service أخرى. كل تبادل بيانات يتم عبر HTTP API.

### init_db() — إنشاء الجداول تلقائياً
كل service تُنشئ جداولها عند أول تشغيل باستخدام `CREATE TABLE IF NOT EXISTS`. لا يوجد migration tool — النظام self-initializing.

---

## Dockerfiles

كل service Python تستخدم نفس النمط:
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

الـ frontends:
```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

---

## Environment Variables

### API Gateway
```env
AUTH_URL=http://auth-service:8001
ACCOUNTS_URL=http://accounts-service:8002
TRANSACTIONS_URL=http://transactions-service:8003
NOTIFICATIONS_URL=http://notifications-service:8004
JWT_SECRET=nova-bank-jwt-secret-2025
```

### Auth Service
```env
DATABASE_URL=postgresql://nova:secret@auth-db:5432/auth_db
JWT_SECRET=nova-bank-jwt-secret-2025
ACCOUNTS_URL=http://accounts-service:8002
```

### Accounts Service
```env
DATABASE_URL=postgresql://nova:secret@accounts-db:5432/accounts_db
NOTIFICATIONS_URL=http://notifications-service:8004
```

### Transactions Service
```env
DATABASE_URL=postgresql://nova:secret@transactions-db:5432/transactions_db
ACCOUNTS_URL=http://accounts-service:8002
NOTIFICATIONS_URL=http://notifications-service:8004
```

### Notifications Service
```env
DATABASE_URL=postgresql://nova:secret@notifications-db:5432/notifications_db
```

> ⚠️ **في الـ production:** يجب تغيير `JWT_SECRET` وكلمات مرور PostgreSQL وتخزينها في Docker Secrets أو Vault.

---

## تشغيل المشروع

### أول تشغيل (build كامل)
```bash
docker compose up --build
```

### تشغيل عادي (بدون إعادة build)
```bash
docker compose up -d
```

### إيقاف مع حفظ البيانات
```bash
docker compose down
```

### إيقاف مع حذف البيانات (reset كامل)
```bash
docker compose down -v
```

### مشاهدة الـ logs
```bash
docker compose logs -f                        # كل الـ services
docker compose logs -f transactions-service   # service محددة
```

### Health check شامل
```bash
curl http://localhost:8000/ready
# {"status":"ready","services":{"auth":"ok","accounts":"ok","transactions":"ok","notifications":"ok"}}
```

---

## المشاكل التي واجهناها في الـ Infrastructure

### 🔴 Bug — Cross-DB JOIN في transactions-service
**المشكلة:** الكود كان يحاول `LEFT JOIN accounts` من `transactions-db` وهو مستحيل في Microservices (كل قاعدة بيانات container مستقل).

**الحل:** حذف الـ JOIN وإبقاء الاستعلام على جداول `transactions-db` فقط.

### 🟡 Race Condition عند Startup
**المشكلة:** الـ services تبدأ قبل أن تكون قواعد البيانات جاهزة تماماً رغم الـ healthcheck.

**الحل:** retry loop داخل كل service (20 محاولة × 3 ثواني = دقيقة كاملة للانتظار).

### 🟡 depends_on لا يكفي وحده
`depends_on` بدون `condition: service_healthy` يبدأ الـ service فور رفع الـ container حتى لو الـ DB لم يقبل connections بعد. الحل: `condition: service_healthy` مع healthcheck مناسب.

---

## Monitoring والـ Logging

كل service تستخدم structured JSON logging:
```python
logging.basicConfig(
    format='{"t":"%(asctime)s","svc":"transactions","msg":"%(message)s"}'
)
```

الـ API Gateway يسجل كل طلب بـ Request ID:
```json
{"t":"2026-04-09 19:39:36","svc":"gateway","msg":"4ffe9a POST /api/teller/audit-log u=8c552a6a... → 200 38ms"}
```

---

## Scaling — ملاحظات للمستقبل

النظام الحالي مصمم للتطوير المحلي. للـ production:
- استبدال Docker Compose بـ **Kubernetes**
- إضافة **Redis** للـ rate limiting الموزع وcaching
- **Message Queue** (RabbitMQ/Kafka) بدل HTTP المباشر بين الـ services
- **SSL/TLS** على Nginx
- **Secrets Management** (Vault / K8s Secrets)
- **Horizontal scaling** للـ transactions-service (الأكثر ضغطاً)
