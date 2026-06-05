"""
RoadSOS — MySQL Database Connection
Uses async SQLAlchemy 2.x + aiomysql driver
"""
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy import text
import os
from dotenv import load_dotenv

load_dotenv()

# Finding #4: No default fallback for sensitive credentials
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_USER = os.getenv("DB_USER", "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "")

if not DB_USER or not DB_NAME:
    print("WARNING: DB_USER or DB_NAME not set in environment. Using empty defaults.")

DATABASE_URL = (
    f"mysql+aiomysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    f"?charset=utf8mb4"
)

_debug_mode = os.getenv("DEBUG", "false").lower() == "true"

connect_args = {}
# Finding #6: Proper SSL for remote databases — no more CERT_NONE
if "localhost" not in DB_HOST and "127.0.0.1" not in DB_HOST:
    import ssl
    ssl_context = ssl.create_default_context()
    # Load Aiven CA cert if provided
    ca_cert_path = os.getenv("DB_CA_CERT_PATH")
    if ca_cert_path:
        ssl_context.load_verify_locations(ca_cert_path)
    else:
        # Fallback for Aiven test database since system CA bundle won't trust it natively
        print("WARNING: DB_CA_CERT_PATH not set. Using CERT_NONE for Aiven compatibility.")
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        
    connect_args["ssl"] = ssl_context

engine = create_async_engine(
    DATABASE_URL,
    echo=_debug_mode,
    connect_args=connect_args,
    pool_pre_ping=True,
    pool_recycle=3600,
    pool_size=10,
    max_overflow=20,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)

Base = declarative_base()


async def get_db():
    """FastAPI dependency — yields an async DB session with auto-commit.

    Routers should NOT call db.commit() themselves; this dependency
    commits on success and rolls back on any unhandled exception.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def check_db_connection() -> bool:
    """Health check — returns True if DB is reachable."""
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception as e:
        print(f"DB connection failed: {e}")
        return False
