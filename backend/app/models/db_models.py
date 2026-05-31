"""
RoadSOS — SQLAlchemy ORM Models
All tables map to roadsos_db MySQL schema.

Table relationships:
  sos_alerts  ──FK──>  accident_reports (optional link)
  accident_reports  ──FK──>  ai_analysis_results (1:1)
  cached_services  (standalone, populated from OSM)
  emergency_numbers  (standalone lookup table)
  service_feedback  ──FK──>  cached_services
  app_logs  (standalone audit/analytics)
  officers (standalone tracking for dispatch)
  device_trust (fake SOS prevention)
"""

from sqlalchemy import (
    Column, Integer, String, Float, DateTime, Text, Enum,
    ForeignKey, Boolean, SmallInteger, Index, JSON
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.utils.database import Base
import enum


# ── Enums ──────────────────────────────────────────────────
class SeverityEnum(str, enum.Enum):
    minor = "minor"
    moderate = "moderate"
    critical = "critical"


class AlertStatusEnum(str, enum.Enum):
    active = "active"
    resolved = "resolved"
    false_alarm = "false_alarm"
    cancelled = "cancelled"
    cancelled_by_police = "cancelled_by_police"
    cancelled_by_citizen = "cancelled_by_citizen"


class AccidentStatusEnum(str, enum.Enum):
    open = "open"
    attended = "attended"
    resolved = "resolved"


class ServiceTypeEnum(str, enum.Enum):
    police = "police"
    hospital = "hospital"
    ambulance = "ambulance"
    towing = "towing"
    puncture = "puncture"
    showroom = "showroom"


# ── 1. SOS Alerts ──────────────────────────────────────────
class SOSAlert(Base):
    __tablename__ = "sos_alerts"

    id = Column(Integer, primary_key=True, autoincrement=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    severity = Column(Enum(SeverityEnum), default=SeverityEnum.critical)
    message = Column(Text, nullable=True)
    device_id = Column(String(100), nullable=True, index=True)
    status = Column(Enum(AlertStatusEnum), default=AlertStatusEnum.active, index=True)
    alert_type = Column(String(50), default="citizen_sos")
    alerted_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    # Overhaul additions
    reporters = Column(JSON, default=list)
    location_update_pending = Column(Boolean, default=False)
    new_lat = Column(Float, nullable=True)
    new_lng = Column(Float, nullable=True)
    closure_notes = Column(Text, nullable=True)
    closure_photo_urls = Column(JSON, default=list)
    
    # Cancellation Details
    cancellation_reason = Column(String(100), nullable=True)
    cancellation_details = Column(Text, nullable=True)
    cancelled_by = Column(String(50), nullable=True)
    
    # Officer Backup Details
    requester_id = Column(Integer, nullable=True)

    # FK link to accident report (optional — set when user also files a report)
    accident_report_id = Column(Integer, ForeignKey("accident_reports.id"), nullable=True)

    # Relationship
    accident_report = relationship("AccidentReport", back_populates="sos_alerts", foreign_keys=[accident_report_id])

    __table_args__ = (
        Index("idx_sos_location", "latitude", "longitude"),
    )

    def __repr__(self) -> str:
        return f"<SOSAlert id={self.id} severity={self.severity} status={self.status}>"


# ── 2. Accident Reports ────────────────────────────────────
class AccidentReport(Base):
    __tablename__ = "accident_reports"

    id = Column(Integer, primary_key=True, autoincrement=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    severity = Column(Enum(SeverityEnum), default=SeverityEnum.moderate, index=True)
    casualties = Column(SmallInteger, default=0)
    description = Column(Text, nullable=True)
    image_path = Column(String(500), nullable=True)
    status = Column(Enum(AccidentStatusEnum), default=AccidentStatusEnum.open, index=True)
    reported_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now(), nullable=True)

    # Relationships
    sos_alerts = relationship("SOSAlert", back_populates="accident_report", foreign_keys="SOSAlert.accident_report_id")
    ai_result = relationship("AIAnalysisResult", back_populates="accident_report", uselist=False)

    __table_args__ = (
        Index("idx_accident_location", "latitude", "longitude"),
    )

    def __repr__(self) -> str:
        return f"<AccidentReport id={self.id} severity={self.severity} status={self.status}>"


# ── 3. AI Analysis Results ─────────────────────────────────
class AIAnalysisResult(Base):
    __tablename__ = "ai_analysis_results"

    id = Column(Integer, primary_key=True, autoincrement=True)
    accident_report_id = Column(Integer, ForeignKey("accident_reports.id"), nullable=True, unique=True)
    detected_objects = Column(Text, nullable=True)      # JSON string
    severity_estimate = Column(String(50), nullable=True)
    confidence_score = Column(Float, nullable=True)
    vehicles_count = Column(SmallInteger, default=0)
    persons_detected = Column(Boolean, default=False)
    recommendations = Column(Text, nullable=True)       # JSON string
    model_used = Column(String(100), default="yolov8n")
    analyzed_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship
    accident_report = relationship("AccidentReport", back_populates="ai_result")

    def __repr__(self) -> str:
        return f"<AIAnalysisResult id={self.id} severity={self.severity_estimate}>"


# ── 4. Cached Services (OSM data) ──────────────────────────
class CachedService(Base):
    __tablename__ = "cached_services"

    id = Column(Integer, primary_key=True, autoincrement=True)
    osm_id = Column(String(100), nullable=True, unique=True)
    name = Column(String(255), nullable=False)
    service_type = Column(Enum(ServiceTypeEnum), nullable=False, index=True)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    phone = Column(String(50), nullable=True)
    address = Column(Text, nullable=True)
    country_code = Column(String(10), default="IN", index=True)
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    last_updated = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationship
    feedbacks = relationship("ServiceFeedback", back_populates="service")

    __table_args__ = (
        Index("idx_service_location", "latitude", "longitude"),
        Index("idx_service_type_country", "service_type", "country_code"),
    )

    def __repr__(self) -> str:
        return f"<CachedService id={self.id} name={self.name!r} type={self.service_type}>"


# ── 5. Emergency Numbers (per country) ────────────────────
class EmergencyNumber(Base):
    __tablename__ = "emergency_numbers"

    id = Column(Integer, primary_key=True, autoincrement=True)
    country_code = Column(String(10), unique=True, nullable=False, index=True)
    country_name = Column(String(100), nullable=True)
    police = Column(String(20), nullable=True)
    ambulance = Column(String(20), nullable=True)
    fire = Column(String(20), nullable=True)
    national_emergency = Column(String(20), default="112")

    def __repr__(self) -> str:
        return f"<EmergencyNumber {self.country_code} ({self.country_name})>"


# ── 6. Service Feedback (user-submitted ratings) ──────────
class ServiceFeedback(Base):
    __tablename__ = "service_feedback"

    id = Column(Integer, primary_key=True, autoincrement=True)
    service_id = Column(Integer, ForeignKey("cached_services.id"), nullable=False, index=True)
    rating = Column(SmallInteger, nullable=False)          # 1–5
    comment = Column(Text, nullable=True)
    device_id = Column(String(100), nullable=True)
    submitted_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship
    service = relationship("CachedService", back_populates="feedbacks")

    def __repr__(self) -> str:
        return f"<ServiceFeedback id={self.id} service={self.service_id} rating={self.rating}>"


# ── 7. App Logs (audit / analytics) ───────────────────────
class AppLog(Base):
    __tablename__ = "app_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    event_type = Column(String(100), nullable=False, index=True)  # SOS_TRIGGERED, SEARCH, REPORT, etc.
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    device_id = Column(String(100), nullable=True)
    log_metadata = Column("metadata", Text, nullable=True)                # JSON string
    logged_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    def __repr__(self) -> str:
        return f"<AppLog id={self.id} event={self.event_type}>"


# ── 8. Officers (Uber-style Dispatch) ─────────────────────
class OfficerStatusEnum(str, enum.Enum):
    offline = "offline"
    available = "available"
    busy = "busy"


class Officer(Base):
    __tablename__ = "officers"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    badge_number = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=True)  # None = accept any (MVP)
    phone = Column(String(20), nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    status = Column(Enum(OfficerStatusEnum), default=OfficerStatusEnum.offline, index=True)
    last_ping_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self) -> str:
        return f"<Officer id={self.id} badge={self.badge_number} status={self.status}>"


# ── 9. Device Trust (Fake SOS Prevention) ─────────────────
class DeviceTrust(Base):
    __tablename__ = "device_trust"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_id = Column(String(100), unique=True, nullable=False, index=True)
    trust_score = Column(Integer, default=100)  # 100 is perfect, < 50 triggers manual review
    false_alarms_count = Column(Integer, default=0)
    last_sos_at = Column(DateTime(timezone=True), nullable=True)

    def __repr__(self) -> str:
        return f"<DeviceTrust device={self.device_id} score={self.trust_score}>"
