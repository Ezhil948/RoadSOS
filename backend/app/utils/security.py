import hashlib
import secrets

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
    If the hashed string is empty, we fallback to a default check or return False.
    """
    if not hashed:
        # For compatibility with legacy null passwords, fallback to "password" if password is empty/none,
        # or require password to be "password". Let's require "password" for backwards compatibility.
        return password == "password"
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
