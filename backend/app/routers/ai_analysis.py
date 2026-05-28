"""AI Analysis router — YOLOv8 accident image analysis."""
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.utils.database import get_db
from app.models.db_models import AIAnalysisResult
from app.models.schemas import AnalysisResult
from typing import Optional, List
import io, json, os

router = APIRouter()

# ── Vehicle class set — O(1) lookup vs O(n) list scan ──
_VEHICLE_CLASSES = frozenset({"car", "truck", "bus", "motorcycle", "bicycle"})

# ── YOLO model singleton — loaded once, reused across all requests ──
_yolo_model = None


def _get_yolo_model():
    """Lazy-load and cache the YOLO model. Returns None if ultralytics is not installed."""
    global _yolo_model
    if _yolo_model is None:
        try:
            from ultralytics import YOLO
            model_path = os.getenv("YOLO_MODEL_PATH", "ai_module/models/accident_detector.pt")
            if not os.path.exists(model_path):
                model_path = "yolov8n.pt"
            _yolo_model = YOLO(model_path)
        except ImportError:
            pass  # _yolo_model stays None → fallback result
    return _yolo_model


@router.post("/analyze", response_model=AnalysisResult, summary="Analyze accident image with YOLOv8")
async def analyze_image(
    image: UploadFile = File(...),
    report_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
):
    try:
        contents = await image.read()
        result = await _run_yolo(contents)

        # Persist result to DB if linked to a report
        if report_id:
            existing = await db.execute(
                select(AIAnalysisResult).where(AIAnalysisResult.accident_report_id == report_id)
            )
            if not existing.scalar_one_or_none():
                db.add(AIAnalysisResult(
                    accident_report_id=report_id,
                    detected_objects=json.dumps(result.detected_objects),
                    severity_estimate=result.severity_estimate,
                    confidence_score=result.confidence,
                    vehicles_count=result.vehicles_count,
                    persons_detected=result.persons_detected,
                    recommendations=json.dumps(result.recommendations),
                ))

        return result
    except Exception as e:
        raise HTTPException(500, f"AI analysis failed: {str(e)}")


async def _run_yolo(image_bytes: bytes) -> AnalysisResult:
    """Run YOLO inference on image bytes. Falls back to stub if model unavailable."""
    model = _get_yolo_model()
    if model is None:
        return _fallback_result()

    from PIL import Image

    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    results = model(img, verbose=False)

    detected: List[str] = []
    vehicles = 0
    persons = False

    for r in results:
        for box in r.boxes:
            cls_name = r.names[int(box.cls)]
            detected.append(cls_name)
            if cls_name in _VEHICLE_CLASSES:
                vehicles += 1
            if cls_name == "person":
                persons = True

    severity = _estimate_severity(persons, vehicles)
    recommendations = _build_recommendations(severity, persons, vehicles)
    confidence = float(results[0].boxes.conf.mean()) if len(results[0].boxes) > 0 else 0.0

    return AnalysisResult(
        detected_objects=list(set(detected)),
        severity_estimate=severity,
        confidence=round(confidence, 2),
        recommendations=recommendations,
        vehicles_count=vehicles,
        persons_detected=persons,
    )


def _fallback_result() -> AnalysisResult:
    """Stub result when YOLO/ultralytics is not available."""
    return AnalysisResult(
        detected_objects=["vehicle"],
        severity_estimate="moderate",
        confidence=0.0,
        recommendations=["Call 112", "Do not move injured"],
        vehicles_count=1,
        persons_detected=False,
    )


def _estimate_severity(persons: bool, vehicles: int) -> str:
    """Heuristic severity from detection counts."""
    if persons and vehicles >= 2:
        return "critical"
    if persons or vehicles >= 2:
        return "moderate"
    return "minor"


def _build_recommendations(severity: str, persons: bool, vehicles: int) -> List[str]:
    """Build actionable recommendations based on analysis."""
    recs = ["Call 112 (National Emergency)"]
    if persons:
        recs.append("Injured persons detected — Call 108 Ambulance")
        recs.append("Do NOT move injured unless immediate danger")
    if vehicles:
        recs.append("Contact towing service for vehicle recovery")
    if severity == "critical":
        recs.append("Secure scene — alert police 100")
    recs.append("Document scene for insurance")
    return recs
