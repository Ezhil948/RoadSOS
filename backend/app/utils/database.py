"""
RoadSOS — MySQL Database Connection
DB: roadsos_db | User: roadsos_admin | Pass: roadsos_pass
Uses async SQLAlchemy 2.x + aiomysql driver
"""
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy import text
import os
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_USER = os.getenv("DB_USER", "roadsos_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "roadsos_pass")
DB_NAME = os.getenv("DB_NAME", "roadsos_db")

DATABASE_URL = (
    f"mysql+aiomysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    f"?charset=utf8mb4"
)

_debug_mode = os.getenv("DEBUG", "false").lower() == "true"

engine = create_async_engine(
    DATABASE_URL,
    echo=_debug_mode,
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
