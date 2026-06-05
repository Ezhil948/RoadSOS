"""
RoadSOS FastAPI Backend
DB: roadsos_db | User: roadsos_admin
Run: uvicorn main:app --reload --host 0.0.0.0 --port 8000
Swagger: http://localhost:8000/docs
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from contextlib import asynccontextmanager
from app.presentation.routers import services, sos, accident, sync, emergency, feedback, logs, dispatch, auth
from app.utils.database import engine, Base, check_db_connection
import os
import time
import asyncio
from collections import defaultdict


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        self.auth_requests = defaultdict(list)
        self.sos_requests = defaultdict(list)  # Finding #8: SOS-specific rate limit
        self.general_requests = defaultdict(list)
        self._cleanup_task = None

    async def _periodic_cleanup(self):
        """Finding #9: Prune stale entries every 5 minutes to prevent memory leaks."""
        while True:
            await asyncio.sleep(300)
            now = time.time()
            for store in [self.auth_requests, self.sos_requests, self.general_requests]:
                stale_keys = [ip for ip, timestamps in store.items()
                              if not timestamps or now - timestamps[-1] > 900]
                for key in stale_keys:
                    del store[key]

    async def dispatch(self, request: Request, call_next):
        # Start cleanup task on first request
        if self._cleanup_task is None:
            self._cleanup_task = asyncio.create_task(self._periodic_cleanup())

        client_ip = request.client.host if request.client else "unknown"
        path = request.url.path
        now = time.time()

        if path.startswith("/api/v1/auth"):
            # Max 5 attempts per 15 minutes (900 seconds)
            self.auth_requests[client_ip] = [t for t in self.auth_requests[client_ip] if now - t < 900]
            if len(self.auth_requests[client_ip]) >= 5:
                retry_after = int(900 - (now - self.auth_requests[client_ip][0]))
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many login attempts. Please try again later."},
                    headers={"Retry-After": str(retry_after)}
                )
            self.auth_requests[client_ip].append(now)

        elif path.startswith("/api/v1/sos/alert"):
            # Finding #8: SOS-specific rate limit — 3 alerts per 10 minutes per IP
            self.sos_requests[client_ip] = [t for t in self.sos_requests[client_ip] if now - t < 600]
            if len(self.sos_requests[client_ip]) >= 3:
                retry_after = int(600 - (now - self.sos_requests[client_ip][0]))
                return JSONResponse(
                    status_code=429,
                    content={"detail": "SOS rate limit exceeded. Max 3 alerts per 10 minutes."},
                    headers={"Retry-After": str(retry_after)}
                )
            self.sos_requests[client_ip].append(now)

        else:
            # General rate limit: 60 requests per 60 seconds
            self.general_requests[client_ip] = [t for t in self.general_requests[client_ip] if now - t < 60]
            if len(self.general_requests[client_ip]) >= 60:
                retry_after = int(60 - (now - self.general_requests[client_ip][0]))
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Rate limit exceeded. Too many requests."},
                    headers={"Retry-After": str(retry_after)}
                )
            self.general_requests[client_ip].append(now)

        return await call_next(request)


class RequestBodySizeLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        path = request.url.path
        limit = 1 * 1024 * 1024  # Default: 1 MB
        
        if path.startswith("/api/v1/accident/report") or path.endswith("/close"):
            limit = 15 * 1024 * 1024  # Endpoints allowing uploads: 15 MB

        content_length_header = request.headers.get("content-length")
        if content_length_header:
            try:
                content_length = int(content_length_header)
                if content_length > limit:
                    return JSONResponse(
                        status_code=413,
                        content={"detail": "Payload too large. Max size exceeded."}
                    )
            except ValueError:
                return JSONResponse(
                    status_code=400,
                    content={"detail": "Invalid Content-Length header."}
                )
        return await call_next(request)


# ── Finding #26: Background alert timeout cleanup ─────────
async def _alert_cleanup_loop():
    """Runs every 30 seconds to cancel timed-out alerts and flag for manual dispatch.
    Moved out of list_sos_alerts() to prevent write operations on every poll.
    """
    from app.utils.database import AsyncSessionLocal
    from app.infrastructure.repositories.sos_repository import SOSRepository
    while True:
        try:
            async with AsyncSessionLocal() as session:
                repo = SOSRepository(session)
                await repo.cancel_timeout_alerts()
                await session.commit()
        except Exception as e:
            print(f"Alert cleanup error: {e}")
        await asyncio.sleep(30)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ──────────────────────────────────────────
    print("RoadSOS API starting up...", flush=True)
    try:
        # Create all tables in roadsos_db
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            
            # Apply migrations individually so one failure doesn't block the rest
            from sqlalchemy import text
            migrations = [
                "ALTER TABLE sos_alerts ADD COLUMN reporters JSON;",
                "ALTER TABLE sos_alerts ADD COLUMN location_update_pending BOOLEAN DEFAULT FALSE;",
                "ALTER TABLE sos_alerts ADD COLUMN new_lat FLOAT;",
                "ALTER TABLE sos_alerts ADD COLUMN new_lng FLOAT;",
                "ALTER TABLE sos_alerts ADD COLUMN closure_notes TEXT;",
                "ALTER TABLE sos_alerts ADD COLUMN closure_photo_urls JSON;",
                "ALTER TABLE sos_alerts ADD COLUMN accident_report_id INTEGER;",
                "ALTER TABLE sos_alerts ADD COLUMN cancellation_reason VARCHAR(255);",
                "ALTER TABLE sos_alerts ADD COLUMN cancellation_details TEXT;",
                "ALTER TABLE sos_alerts ADD COLUMN cancelled_by VARCHAR(255);",
                "ALTER TABLE sos_alerts ADD COLUMN requester_id VARCHAR(255);",
                "ALTER TABLE sos_alerts ADD COLUMN alert_type VARCHAR(50) DEFAULT 'citizen_sos';",
                "ALTER TABLE sos_alerts ADD COLUMN pinged_officer_ids JSON;",
                "ALTER TABLE sos_alerts ADD COLUMN rejected_officer_ids JSON;",
                "ALTER TABLE sos_alerts ADD COLUMN accepted_officer_id INTEGER;",
                "ALTER TABLE sos_alerts ADD COLUMN requires_manual_dispatch BOOLEAN DEFAULT FALSE;",
                "ALTER TABLE sos_alerts ADD COLUMN category VARCHAR(100) NULL;",
                "ALTER TABLE sos_alerts ADD COLUMN citizen_name VARCHAR(255);",
                "ALTER TABLE sos_alerts ADD COLUMN citizen_phone VARCHAR(50);",
                "ALTER TABLE sos_alerts MODIFY COLUMN status VARCHAR(30) DEFAULT 'active';",
            ]
            for mig in migrations:
                try:
                    await conn.execute(text(mig))
                except Exception:
                    pass
            
            # Finding #20: Add composite index on officers for dispatch lookup
            try:
                await conn.execute(text(
                    "CREATE INDEX idx_officer_dispatch_lookup ON officers (status, latitude, longitude)"
                ))
            except Exception:
                pass  # Index may already exist
            
            print("Applied schema migrations successfully.")

        db_ok = await check_db_connection()
        print(f"   MySQL roadsos_db: {'OK Connected' if db_ok else 'FAILED'}", flush=True)
        print(f"   User: roadsos_admin @ {os.getenv('DB_HOST', 'localhost')}", flush=True)
    except Exception as e:
        import traceback
        print(f"CRITICAL ERROR during database startup: {e}", flush=True)
        traceback.print_exc()
        # Do not raise here; allow Uvicorn to start so Render deploy succeeds and we can see the logs!
    
    # Start background cleanup task (Finding #26)
    cleanup_task = asyncio.create_task(_alert_cleanup_loop())
    
    yield
    # ── Shutdown ─────────────────────────────────────────
    cleanup_task.cancel()
    print("RoadSOS API shutting down...")
    await engine.dispose()


app = FastAPI(
    title="RoadSOS API",
    description="""
## 🚨 RoadSOS — Emergency Response Backend

**IIT Madras COERS 2026 Hackathon**

### Endpoints
| Group | Purpose |
|---|---|
| `/api/v1/services` | Nearby police, hospital, ambulance, towing, puncture, showroom |
| `/api/v1/sos` | SOS alert trigger and management |
| `/api/v1/accident` | Accident report submission |
| `/api/v1/emergency` | Country emergency numbers |
| `/api/v1/feedback` | Service ratings |
| `/api/v1/sync` | Offline bundle pre-fetch |
| `/api/v1/logs` | App event logging |

**Database:** `roadsos_db` (MySQL 8.0)  
**Maps:** OpenStreetMap (free, no API key, global)
    """,
    version="2.0.0",
    lifespan=lifespan,
)

# ── Finding #5: CORS lockdown — no more wildcard ──────────
ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "http://localhost:5173,http://localhost:3000").split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestBodySizeLimitMiddleware)

# ── Routers ────────────────────────────────────────────────
_ROUTERS = [
    (services.router,    "/api/v1/services",  ["Services"]),
    (sos.router,         "/api/v1/sos",       ["SOS"]),
    (accident.router,    "/api/v1/accident",   ["Accident"]),
    (emergency.router,   "/api/v1/emergency", ["Emergency Numbers"]),
    (feedback.router,    "/api/v1/feedback",   ["Feedback"]),
    (sync.router,        "/api/v1/sync",       ["Offline Sync"]),
    (logs.router,        "/api/v1/logs",       ["Logs"]),
    (dispatch.router,    "/api/v1/dispatch",   ["Dispatch"]),
    (auth.router,        "/api/v1/auth",       ["Auth"]),
]
for router_module, prefix, tags in _ROUTERS:
    app.include_router(router_module, prefix=prefix, tags=tags)


@app.get("/health", tags=["Health"])
async def health():
    db_ok = await check_db_connection()
    return {
        "status": "ok" if db_ok else "degraded",
        "service": "RoadSOS API v2.0",
        "database": "connected" if db_ok else "unreachable",
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", 8000)),
        reload=True,
    )
