"""Nova Bank — Notifications Service :8004"""
import os, logging, time
import psycopg2, psycopg2.extras
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

DB_URL = os.getenv("DATABASE_URL")
logging.basicConfig(level=logging.INFO,
  format='{"t":"%(asctime)s","svc":"notifications","msg":"%(message)s"}')
log = logging.getLogger(__name__)

app = FastAPI(title="Notifications Service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

def conn():
    return psycopg2.connect(DB_URL, cursor_factory=psycopg2.extras.RealDictCursor)

def init_db():
    with conn() as c:
        with c.cursor() as cur:
            cur.execute("""
            CREATE TABLE IF NOT EXISTS notifications (
                id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id    UUID NOT NULL,
                title      TEXT NOT NULL,
                body       TEXT NOT NULL,
                type       TEXT DEFAULT 'system',
                read       BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id);
            """)
        c.commit()

def row2dict(r):
    d = dict(r)
    for k,v in d.items():
        if hasattr(v,'isoformat'): d[k] = v.isoformat()
    return d

@app.on_event("startup")
def startup():
    for i in range(20):
        try: init_db(); log.info("Notifications DB ready"); return
        except Exception as e: log.warning(f"DB not ready ({i+1}/20): {e}"); time.sleep(3)
    raise RuntimeError("Notifications DB failed")

@app.get("/health")
def health(): return {"status":"ok","service":"notifications-service"}

@app.get("/notifications/{user_id}")
def get_notifications(user_id: str):
    with conn() as c:
        with c.cursor() as cur:
            cur.execute("SELECT * FROM notifications WHERE user_id=%s ORDER BY created_at DESC",(user_id,))
            rows = [row2dict(r) for r in cur.fetchall()]
    unread = sum(1 for r in rows if not r["read"])
    return {"notifications":rows,"unreadCount":unread}

@app.put("/notifications/{user_id}/read/{notif_id}")
def mark_read(user_id: str, notif_id: str):
    with conn() as c:
        with c.cursor() as cur:
            cur.execute("UPDATE notifications SET read=TRUE WHERE id=%s AND user_id=%s",(notif_id,user_id))
            if cur.rowcount==0: raise HTTPException(404,"الإشعار غير موجود")
        c.commit()
    return {"ok":True}

@app.put("/notifications/{user_id}/read-all")
def mark_all_read(user_id: str):
    with conn() as c:
        with c.cursor() as cur:
            cur.execute("UPDATE notifications SET read=TRUE WHERE user_id=%s",(user_id,))
        c.commit()
    return {"ok":True}

@app.post("/internal/create")
def create(data: dict):
    with conn() as c:
        with c.cursor() as cur:
            cur.execute("INSERT INTO notifications(user_id,title,body,type) VALUES(%s,%s,%s,%s) RETURNING *",
                        (data["user_id"],data["title"],data["body"],data.get("type","system")))
            n = row2dict(cur.fetchone())
        c.commit()
    return {"ok":True,"notification":n}
