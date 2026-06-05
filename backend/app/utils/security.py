import hashlib
import secrets
import jwt
import os
from datetime import datetime, timezone, timedelta
from fastapi import Request, HTTPException, Depends

# ── JWT Configuration ──────────────────────────────────────
JWT_SECRET = os.getenv("JWT_SECRET", "")
JWT_ALGORITHM = "HS256"
JWT_EXPIRY_HOURS = 24

def _ensure_jwt_secret():
    """Validate JWT_SECRET is set. Called lazily on first token operation."""
    if not JWT_SECRET:
        raise RuntimeError(
            "JWT_SECRET environment variable must be set. "
            "Generate one with: python -c \"import secrets; print(secrets.token_hex(32))\""
        )

# ── Password Hashing ──────────────────────────────────────
def hash_password(password: str, salt: bytes = None) -> str:
    """Hash a password using PBKDF2-HMAC-SHA256 with 100,000 iterations.
    Returns: salt_hex$hash_hex
    """
    if not password:
        return ""
    if salt is None:
        salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    return f"{salt.hex()}${dk.hex()}"

def verify_password(password: str, hashed: str) -> bool:
    """Verify password against a salt_hex$hash_hex string.
    Officers without a password hash CANNOT log in — admin must set one.
    """
    if not hashed:
        # SECURITY FIX (Finding #7): No backdoor — officers without hashes are locked out
        return False
    try:
        parts = hashed.split('$')
        if len(parts) != 2:
            return False
        salt_hex, hash_hex = parts
        salt = bytes.fromhex(salt_hex)
        expected = hash_password(password, salt)
        return expected == hashed
    except Exception:
        return False


# ── JWT Token Operations ──────────────────────────────────
def create_access_token(officer_id: int, badge_number: str) -> str:
    """Create a signed JWT for an authenticated officer."""
    _ensure_jwt_secret()
    payload = {
        "sub": str(officer_id),
        "badge": badge_number,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRY_HOURS),
        "iss": "roadsos-api",
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def verify_token(token: str) -> dict:
    """Verify and decode a JWT. Raises HTTPException on failure."""
    _ensure_jwt_secret()
    try:
        payload = jwt.decode(
            token, JWT_SECRET,
            algorithms=[JWT_ALGORITHM],
            options={"require": ["sub", "exp", "iss"]},
        )
        if payload.get("iss") != "roadsos-api":
            raise HTTPException(status_code=401, detail="Invalid token issuer")
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


# ── FastAPI Dependencies ──────────────────────────────────
async def get_current_officer(request: Request) -> int:
    """FastAPI dependency — extracts and verifies the officer_id from a Bearer token.
    Returns the authenticated officer's integer ID.
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing authentication token")
    token = auth_header.split(" ", 1)[1]
    payload = verify_token(token)
    try:
        return int(payload["sub"])
    except (ValueError, KeyError):
        raise HTTPException(status_code=401, detail="Malformed token payload")
