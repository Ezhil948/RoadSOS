"""Pydantic schemas for request and response validation."""
from pydantic import BaseModel, Field
from typing import Optional, List

# ── Auth ───────────────────────────────────────────────────
class LoginRequest(BaseModel):
    badge_number: str = Field(..., max_length=30)
    password: str = Field(..., max_length=128)

class LoginResponse(BaseModel):
    officer_id: int
    name: str
    badge_number: str
    status: str


# ── SOS Alerts ─────────────────────────────────────────────
class SOSRequest(BaseModel):
    latitude: float
    longitude: float
    severity: str = Field("critical", max_length=20)
    message: Optional[str] = Field(None, max_length=1000)
    device_id: Optional[str] = Field(None, max_length=100)
    citizen_name: Optional[str] = Field(None, max_length=255)
    citizen_phone: Optional[str] = Field(None, max_length=50)

class SOSResponse(BaseModel):
    status: str
    alert_id: int
    message: str
    nearest_emergency: str = "112"
    action: str = "CALL_112"

class ResolveRequest(BaseModel):
    officer_notes: Optional[str] = Field(None, max_length=1000)

class CitizenCancelRequest(BaseModel):
    reason: Optional[str] = None

class PoliceCancelRequest(BaseModel):
    reason: str = Field(..., max_length=100)
    details: Optional[str] = Field(None, max_length=1000)

class OfficerBackupRequest(BaseModel):
    latitude: float
    longitude: float
    message: Optional[str] = None


# ── Accident Reports ───────────────────────────────────────
class StatusUpdate(BaseModel):
    status: str


# ── Dispatch / Officers ────────────────────────────────────
class LocationPing(BaseModel):
    latitude: float
    longitude: float
    status: str = Field(..., max_length=30)

class DispatchResponse(BaseModel):
    action: str  # "accept" or "reject"


