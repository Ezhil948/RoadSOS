"""Pydantic schemas for request and response validation."""
from pydantic import BaseModel
from typing import Optional, List

# ── Auth ───────────────────────────────────────────────────
class LoginRequest(BaseModel):
    badge_number: str
    password: str

class LoginResponse(BaseModel):
    officer_id: int
    name: str
    badge_number: str
    status: str


# ── SOS Alerts ─────────────────────────────────────────────
class SOSRequest(BaseModel):
    latitude: float
    longitude: float
    severity: str = "critical"
    message: Optional[str] = None
    device_id: Optional[str] = None

class SOSResponse(BaseModel):
    status: str
    alert_id: int
    message: str
    nearest_emergency: str = "112"
    action: str = "CALL_112"

class ResolveRequest(BaseModel):
    officer_notes: Optional[str] = None


# ── Accident Reports ───────────────────────────────────────
class StatusUpdate(BaseModel):
    status: str


# ── Dispatch / Officers ────────────────────────────────────
class LocationPing(BaseModel):
    latitude: float
    longitude: float
    status: str

class DispatchResponse(BaseModel):
    action: str  # "accept" or "reject"


# ── AI Analysis ────────────────────────────────────────────
class AnalysisResult(BaseModel):
    detected_objects: List[str]
    severity_estimate: str
    confidence: float
    recommendations: List[str]
    vehicles_count: int
    persons_detected: bool
