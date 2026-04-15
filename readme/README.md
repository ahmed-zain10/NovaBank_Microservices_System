# 🏦 NovaBankنظام إدارة البنك الرقمي

> منصة بنكية متكاملة مبنية على معمارية Microservices — تتيح للعملاء إدارة حساباتهم وللموظفين تنفيذ العمليات البنكية اليومية وللإدارة الإشراف الكامل على المنظومة.

---

## 📌 نظرة عامة

NovaBank هو نظام بنكي رقمي كامل يتكون من واجهتين للمستخدم (عملاء / موظفو الخزينة) وخمسة microservices مستقلة، كل منها بقاعدة بيانات خاصة به، تتواصل فيما بينها عبر HTTP من خلال API Gateway مركزي.

---

## 🧩 المحاور الرئيسية للمشروع

| المحور | التقنيات المستخدمة |
|--------|-------------------|
| **Backend / Microservices** | Python · FastAPI · psycopg2 · httpx · python-jose |
| **Databases** | PostgreSQL 15 (قاعدة بيانات مستقلة لكل service) |
| **Frontend** | HTML5 · CSS3 · Vanilla JavaScript (Single-page apps) |
| **Infrastructure** | Docker · Docker Compose · Nginx (reverse proxy + static serving) |
| **Auth & Security** | JWT (HS256) · bcrypt · Rate Limiting · Role-based access control |
| **Notifications** | Internal HTTP push → notifications-service → PostgreSQL |

---

## 🏗️ معمارية النظام

```
                         ┌─────────────────┐
                         │   Nginx :8080   │  ← Reverse Proxy
                         └────────┬────────┘
                    ┌─────────────┴─────────────┐
           :3000    ▼                           ▼   :3001
    ┌──────────────────┐              ┌──────────────────┐
    │ frontend-customers│              │  frontend-teller  │
    └──────────────────┘              └──────────────────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                        ┌─────────────────┐
                        │  API Gateway    │  :8000  ← JWT · Rate Limit · Routing
                        └────────┬────────┘
           ┌────────────┬────────┼────────────┬─────────────┐
           ▼            ▼        ▼            ▼             ▼
      auth-svc    accounts-svc  txn-svc  notif-svc       (...)
      :8001        :8002        :8003     :8004
         │            │           │          │
      auth-db    accounts-db  txn-db    notif-db
```

---

## 🎯 الفيتشرز الرئيسية

### 👤 بوابة العملاء (frontend-customers :3000)
- تسجيل حساب جديد / تسجيل دخول
- لوحة تحكم بالرصيد والمعاملات الأخيرة
- تحويل أموال بالرقم أو البريد الإلكتروني
- دفع الفواتير (كهرباء، مياه، اتصالات، إلخ)
- صرف العملات الأجنبية بأسعار فورية
- إدارة البطاقات البنكية
- أهداف الادخار والقروض
- محفظة استثمارية (أسهم)
- إشعارات فورية لكل عملية
- تغيير كلمة المرور

### 🏧 بوابة الخزينة (frontend-teller :3001)
- تسجيل دخول الموظفين برقم الموظف وكلمة المرور
- عرض جميع الحسابات والبحث والتصفية
- إيداع / سحب / تحويل / دفع فواتير على الحسابات
- تجميد / إلغاء تجميد الحسابات
- إنشاء عملاء جدد
- سجل عمليات اليوم (teller-log-today)
- سجل كامل وإحصاءات أسبوعية
- سجل مراجعة (audit log)
- لوحة مراقبة لمدراء الفروع

### 🔒 نظام الأمان
- JWT مع انتهاء صلاحية + RBAC (customer / teller / supervisor / admin)
- Rate limiting على login endpoints
- تشفير كلمات المرور بـ bcrypt
- قواعد بيانات مفصولة تماماً لكل service

---

## 🐳 تشغيل المشروع

```bash
git clone <repo>
cd nova_final
docker compose up --build
```

| الخدمة | الرابط |
|--------|--------|
| بوابة العملاء | http://localhost:3000 |
| بوابة الخزينة | http://localhost:3001 |
| API Gateway | http://localhost:8000 |
| Health Check | http://localhost:8000/ready |

---

## 📁 هيكل المشروع

```
nova_final/
├── docker-compose.yml
├── infrastructure/
│   └── nginx/nginx.conf
└── services/
    ├── api-gateway/
    ├── auth-service/
    ├── accounts-service/
    ├── transactions-service/
    ├── notifications-service/
    ├── frontend-customers/
    └── frontend-teller/
```

---

## 📄 التوثيق التقني التفصيلي

| الملف | المحتوى |
|-------|---------|
| `README.backend.md` | توثيق الـ backend والـ microservices |
| `README.frontend.md` | توثيق الـ frontend وتدفق الـ UI |
| `README.devops.md` | توثيق البنية التحتية والـ Docker |
| `TECHNICAL_REPORT.md` | تقرير المشاكل والحلول والتطويرات |

---

*NovaBank v2.2 — Built with FastAPI · PostgreSQL · Docker*


<div align="center">

# 🏦 Nova Bank — البنك الرقمي المتكامل

<img src="https://img.shields.io/badge/Architecture-Microservices-0A0F1E?style=for-the-badge&logo=docker&logoColor=C9A84C"/>
<img src="https://img.shields.io/badge/Backend-FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white"/>
<img src="https://img.shields.io/badge/Database-PostgreSQL-336791?style=for-the-badge&logo=postgresql&logoColor=white"/>
<img src="https://img.shields.io/badge/Gateway-Nginx-009900?style=for-the-badge&logo=nginx&logoColor=white"/>
<img src="https://img.shields.io/badge/Auth-JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white"/>
<img src="https://img.shields.io/badge/Frontend-HTML%2FCSS%2FJS-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black"/>
<img src="https://img.shields.io/badge/Containers-Docker%20Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>

<br/>
<br/>

> **نظام بنكي رقمي كامل مبني بمعمارية Microservices حقيقية — يشمل بوابة API، خدمات مستقلة، قواعد بيانات معزولة، لوحة عملاء ولوحة موظفين، كل ذلك منشور بـ Docker في ضغطة زر واحدة.**

<br/>

![Nova Bank Preview](https://via.placeholder.com/900x400/0A0F1E/C9A84C?text=Nova+Bank+%7C+Digital+Banking+Platform)

</div>

---

## 🎯 ما هو Nova Bank؟

**Nova Bank** ليس مجرد واجهة بنكية — بل هو نظام بنكي متكامل مبني بنفس المعمارية التي تستخدمها البنوك الحقيقية في العالم. المشروع يجسّد مفهوم **Microservices Architecture** من الصفر: كل خدمة تعيش في container مستقل، لها قاعدة بياناتها الخاصة، وتتواصل مع بقية الخدمات عبر HTTP.

### ✨ لماذا Nova Bank مختلف؟

| جانب | التفاصيل |
|------|----------|
| 🏗️ **المعمارية** | Microservices حقيقية — 6 خدمات مستقلة + 4 قواعد بيانات معزولة |
| 🔐 **الأمان** | JWT Authentication، bcrypt hashing، Rate Limiting، Role-Based Access |
| 👥 **المستخدمون** | واجهتان منفصلتان — لوحة العملاء ولوحة الموظفين (Teller System) |
| 💱 **العمليات** | إيداع، سحب، تحويل، دفع فواتير، تحويل عملات، قروض، محفظة أسهم |
| 🌐 **اللغة** | دعم كامل للعربية RTL في الواجهات الأمامية |
| 🚀 **النشر** | Docker Compose واحد يشغّل كل شيء |

---

## 🛠️ التقنيات المستخدمة

### Backend
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=flat-square&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.111.0-009688?style=flat-square&logo=fastapi)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?style=flat-square&logo=postgresql)
![Uvicorn](https://img.shields.io/badge/Uvicorn-ASGI-499848?style=flat-square)

### Security
![JWT](https://img.shields.io/badge/JWT-HS256-000000?style=flat-square&logo=jsonwebtokens)
![bcrypt](https://img.shields.io/badge/bcrypt-4.1.3-red?style=flat-square)
![CORS](https://img.shields.io/badge/CORS-Configured-orange?style=flat-square)

### Infrastructure
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker)
![Nginx](https://img.shields.io/badge/Nginx-Reverse%20Proxy-009900?style=flat-square&logo=nginx)

### Frontend
![HTML5](https://img.shields.io/badge/HTML5-Vanilla-E34F26?style=flat-square&logo=html5)
![CSS3](https://img.shields.io/badge/CSS3-RTL%20Support-1572B6?style=flat-square&logo=css3)
![JavaScript](https://img.shields.io/badge/JavaScript-ES6+-F7DF1E?style=flat-square&logo=javascript)

---

## 🏛️ معمارية النظام

```
                        ┌─────────────────────────────────────────┐
                        │              CLIENT BROWSER              │
                        │   frontend-customers   frontend-teller   │
                        │       :3000                 :3001        │
                        └──────────────┬──────────────────────────┘
                                       │ HTTP Requests
                        ┌──────────────▼──────────────────────────┐
                        │           NGINX (Reverse Proxy)          │
                        │                  :8080                   │
                        │   Rate Limiting │ SSL Termination        │
                        └──────────────┬──────────────────────────┘
                                       │
                        ┌──────────────▼──────────────────────────┐
                        │            API GATEWAY                   │
                        │               :8000                      │
                        │  JWT Auth │ Rate Limit │ Logging │ RBAC  │
                        └────┬──────────┬────────────┬────────────┘
                             │          │            │
          ┌──────────────────▼─┐  ┌─────▼───────┐  ┌▼──────────────────┐
          │    AUTH SERVICE    │  │  ACCOUNTS   │  │  TRANSACTIONS     │
          │       :8001        │  │   SERVICE   │  │     SERVICE       │
          │  Login / Register  │  │    :8002    │  │      :8003        │
          │  Employee Auth     │  │  Accounts   │  │  Deposit/Withdraw │
          │  JWT Generation    │  │  Cards      │  │  Transfer         │
          └────────┬───────────┘  │  Goals      │  │  Pay Bills        │
                   │              │  Loans      │  │  Exchange FX      │
          ┌────────▼─────┐        │  Portfolio  │  └────────┬──────────┘
          │   auth-db    │        └──────┬──────┘           │
          │  PostgreSQL  │               │          ┌────────▼──────────┐
          └──────────────┘       ┌───────▼──────┐   │  NOTIFICATIONS    │
                                 │ accounts-db  │   │     SERVICE       │
                                 │  PostgreSQL  │   │      :8004        │
                                 └──────────────┘   └────────┬──────────┘
                                                    ┌────────▼──────────┐
                                                    │ notifications-db  │
                                                    │   PostgreSQL      │
                                                    └───────────────────┘
```

---

## 📁 هيكل المشروع

```
nova_final/
├── 📄 docker-compose.yml          # يشغّل كل شيء بأمر واحد
│
├── 🌐 infrastructure/
│   └── nginx/
│       └── nginx.conf              # Reverse proxy + Rate limiting
│
└── 🔧 services/
    ├── api-gateway/                # بوابة API المركزية
    │   ├── main.py
    │   ├── Dockerfile
    │   └── requirements.txt
    │
    ├── auth-service/               # خدمة المصادقة والمستخدمين
    │   ├── main.py
    │   ├── Dockerfile
    │   └── requirements.txt
    │
    ├── accounts-service/           # خدمة الحسابات
    │   ├── main.py
    │   ├── Dockerfile
    │   └── requirements.txt
    │
    ├── transactions-service/       # خدمة المعاملات المالية
    │   ├── main.py
    │   ├── Dockerfile
    │   └── requirements.txt
    │
    ├── notifications-service/      # خدمة الإشعارات
    │   ├── main.py
    │   ├── Dockerfile
    │   └── requirements.txt
    │
    ├── frontend-customers/         # واجهة العملاء (Arabic RTL)
    │   ├── index.html
    │   ├── nginx.conf
    │   └── Dockerfile
    │
    └── frontend-teller/            # واجهة الموظفين
        ├── index.html
        ├── nginx.conf
        └── Dockerfile
```

---

## 🚀 تشغيل المشروع

### المتطلبات
- **Docker** v20.10+
- **Docker Compose** v2.0+

### خطوة واحدة فقط 🎉

```bash
# 1. Clone المشروع
git clone https://github.com/your-username/novabank.git
cd novabank/nova_final

# 2. شغّل كل شيء
docker compose up --build

# 3. انتظر 30-60 ثانية للـ initialization
# 4. افتح المتصفح 🎊
```

### الروابط بعد التشغيل

| الخدمة | الرابط | الوصف |
|--------|--------|-------|
| 🏠 **Customer Portal** | http://localhost:3000 | بوابة العملاء |
| 👨‍💼 **Teller System** | http://localhost:3001 | لوحة الموظفين |
| 🔌 **API Gateway** | http://localhost:8000 | نقطة API المركزية |
| 🌐 **Nginx Proxy** | http://localhost:8080 | Reverse Proxy |

### بيانات الدخول التجريبية

**عملاء:**
| الاسم | الإيميل | كلمة المرور | نوع الحساب |
|-------|---------|------------|-----------|
| أحمد محمد | demo@novabank.eg | demo123 | Premium |
| نور علي | nour.ali@gmail.com | nour123 | Standard |
| تامر حسن | tamer.h@outlook.com | tamer456 | Business |

**موظفون:**
| الاسم | اسم المستخدم | كلمة المرور | الدور |
|-------|------------|------------|-------|
| محمد السيد | m.elsayed | teller123 | Teller |
| سارة أحمد | s.ahmed | teller456 | Supervisor |
| كريم عبدالله | k.abdallah | admin789 | Admin |

---

## 🔐 نظام الصلاحيات (RBAC)

```
customer    → قراءة وعمليات على حسابه فقط
teller      → عمليات على حسابات العملاء + تقارير
supervisor  → صلاحيات teller + إدارة الموظفين
admin       → صلاحيات كاملة على النظام
```

---

## 📡 API Endpoints الرئيسية

<details>
<summary>🔑 Auth Endpoints</summary>

```http
POST /api/auth/login           # تسجيل دخول عميل
POST /api/auth/login-employee  # تسجيل دخول موظف
POST /api/auth/register        # تسجيل حساب جديد
POST /api/auth/change-password # تغيير كلمة المرور
POST /api/auth/logout          # تسجيل الخروج
```
</details>

<details>
<summary>💰 Accounts Endpoints</summary>

```http
GET  /api/accounts/me                    # بيانات حسابي
GET  /api/accounts/{id}/cards            # كروتي
POST /api/accounts/{id}/cards            # إصدار كارت جديد
GET  /api/accounts/{id}/goals            # أهداف الادخار
POST /api/accounts/{id}/goals            # هدف ادخار جديد
GET  /api/accounts/{id}/loans            # قروضي
POST /api/accounts/{id}/loans            # طلب قرض
GET  /api/accounts/{id}/portfolio        # محفظة الأسهم
POST /api/accounts/{id}/portfolio        # شراء سهم
```
</details>

<details>
<summary>💸 Transactions Endpoints</summary>

```http
POST /api/transactions/deposit   # إيداع
POST /api/transactions/withdraw  # سحب
POST /api/transactions/transfer  # تحويل
POST /api/transactions/pay-bill  # دفع فاتورة
POST /api/transactions/exchange  # تحويل عملة
GET  /api/transactions/rates     # أسعار الصرف
GET  /api/transactions/{id}      # سجل المعاملات
```
</details>

<details>
<summary>🔔 Notifications Endpoints</summary>

```http
GET /notifications/{user_id}                    # إشعاراتي
PUT /notifications/{user_id}/read/{notif_id}   # قراءة إشعار
PUT /notifications/{user_id}/read-all           # قراءة الكل
```
</details>

---

## 🔒 Security Features

- ✅ **JWT Tokens** — HS256 مع انتهاء صلاحية 8 ساعات
- ✅ **bcrypt Password Hashing** — cost factor 12
- ✅ **Rate Limiting** — 60 req/s عام، 5 req/min لـ login
- ✅ **Role-Based Access Control** — 4 مستويات صلاحيات
- ✅ **CORS** — مضبوط لكل الخدمات
- ✅ **Request Logging** — كل request بـ UUID فريد
- ✅ **DB Health Checks** — retry loop حتى 20 محاولة
- ✅ **Balance Constraint** — CHECK (balance >= 0) على DB مستوى

---

## 💱 العملات المدعومة

| العملة | الرمز | معدل التحويل |
|--------|-------|-------------|
| جنيه مصري | EGP | 1.0 (base) |
| دولار أمريكي | USD | 0.0204 |
| يورو | EUR | 0.0188 |
| جنيه إسترليني | GBP | 0.016 |
| ريال سعودي | SAR | 0.0765 |
| درهم إماراتي | AED | 0.0749 |
| دينار كويتي | KWD | 0.00626 |

---

## 🗄️ قواعد البيانات

| الخدمة | DB | الجداول الرئيسية |
|--------|----|----|
| auth-service | auth_db | users, employees, audit_log |
| accounts-service | accounts_db | accounts, cards, savings_goals, loans, portfolio |
| transactions-service | transactions_db | transactions, teller_log, audit_log |
| notifications-service | notifications_db | notifications |

---

## 🤝 المساهمة

المشروع مفتوح للتطوير. يمكن إضافة:
- [ ] 2FA Authentication
- [ ] Kafka/RabbitMQ للـ Event-Driven communication
- [ ] Redis للـ Caching
- [ ] Kubernetes deployment manifests
- [ ] API Documentation بـ Swagger/OpenAPI

---

## 📄 الترخيص

هذا المشروع أكاديمي مفتوح المصدر.

---

<div align="center">

**صُنع بـ ❤️ و ☕ | Nova Bank — مشروع التخرج**

*"The best way to predict the future is to build it."*

</div>

