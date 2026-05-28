# YOLOv8 Accident Detection — Training Notes

## MVP Approach
For the hackathon MVP, use the base YOLOv8n model which already detects:
- car, truck, bus, motorcycle, bicycle (vehicles)
- person (casualties)
- traffic light, stop sign (road context)

The backend's `_estimate_severity()` logic maps these COCO detections
to accident severity without needing a custom model.

## Fine-tuning (Post-Hackathon)
To improve accuracy, fine-tune on accident datasets:
1. ACLED Road Incidents dataset
2. Kaggle: Car Accident Detection Dataset
3. Custom labeled images from Indian roads

```bash
# Install
pip install ultralytics

# Download base model
yolo download model=yolov8n.pt

# Fine-tune (requires labeled dataset in YOLO format)
yolo train model=yolov8n.pt data=accident_data.yaml epochs=50 imgsz=640

# Export
yolo export model=best.pt format=onnx  # for production
```

## Model Placement
Place trained model at: `backend/ai_module/models/accident_detector.pt`
Set env var: `YOLO_MODEL_PATH=ai_module/models/accident_detector.pt`

If file doesn't exist, backend auto-downloads yolov8n.pt from ultralytics.
