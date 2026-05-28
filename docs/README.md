# 🚨 RoadSOS v2.0 — Emergency Response App

**IIT Madras COERS 2026 Hackathon**  
Platform: Unstop | Stack: Flutter + FastAPI + YOLOv8 + MySQL

---

## 🗄️ Database Setup

### Quick start (run once)
```bash
mysql -u root -p < database/schema.sql
```

This script automatically:
- Creates `roadsos_db` database
- Creates `roadsos_admin` user with `roadsos_pass`
- Creates all 7 tables with foreign keys and indexes
- Seeds 11 countries' emergency numbers
- Seeds 14 sample service locations (Chennai + Bengaluru)

### Manual steps (if needed)
```sql
CREATE DATABASE roadsos_db CHARACTER SET utf8mb4;
CREATE USER 'roadsos_admin'@'localhost' IDENTIFIED BY 'roadsos_pass';
GRANT ALL PRIVILEGES ON roadsos_db.* TO 'roadsos_admin'@'localhost';
FLUSH PRIVILEGES;
```

---

## 🏗️ Database Schema (7 Tables)

```
sos_alerts  ──FK──>  accident_reports  ──FK──>  ai_analysis_results
                                                       (1:1)
cached_services  ──FK──>  service_feedback
emergency_numbers  (standalone lookup)
app_logs  (standalone audit)
```

| Table | Purpose |
|---|---|
| `sos_alerts` | SOS button presses — lat/lng/severity/device |
| `accident_reports` | User-filed accident reports with images |
| `ai_analysis_results` | YOLOv8 output linked to each report |
| `cached_services` | OSM data cached locally for offline fallback |
| `emergency_numbers` | Police/ambulance/fire per country |
| `service_feedback` | User ratings (1–5 stars) per service |
| `app_logs` | All app events for analytics |

---

## 🚀 Backend Quick Start

```bash
cd backend
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt

# DB already configured in .env:
# DB_USER=roadsos_admin  DB_PASSWORD=roadsos_pass  DB_NAME=roadsos_db

uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Swagger UI:** `http://localhost:8000/docs`  
**Health check:** `http://localhost:8000/health`

---

## 📡 API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/v1/services/nearby` | Nearest services (OSM live + DB fallback) |
| GET | `/api/v1/services/types` | List all service categories |
| POST | `/api/v1/sos/alert` | Trigger SOS |
| GET | `/api/v1/sos/alerts` | List SOS history |
| PATCH | `/api/v1/sos/alerts/{id}/resolve` | Resolve alert |
| POST | `/api/v1/accident/report` | File accident report |
| GET | `/api/v1/accident/reports` | List reports |
| GET | `/api/v1/accident/reports/{id}` | Get report |
| POST | `/api/v1/ai/analyze` | YOLOv8 image analysis |
| GET | `/api/v1/emergency/numbers` | All country numbers |
| GET | `/api/v1/emergency/numbers/{code}` | Country-specific |
| POST | `/api/v1/feedback/submit` | Rate a service |
| GET | `/api/v1/feedback/service/{id}` | Get service ratings |
| GET | `/api/v1/sync/offline-data` | Bundle for offline cache |
| POST | `/api/v1/logs/event` | Log app event |
| GET | `/api/v1/logs/recent` | Recent logs |
| GET | `/health` | DB + API health check |

---

## 📱 Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

Change API base URL in `lib/utils/constants.dart`:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- Real device: `http://<your-machine-ip>:8000`

---

## 📊 Evaluation Criteria Coverage

| Criteria | Implementation |
|---|---|
| Reliability & Data Accuracy | OSM live → DB cache → Hive local (3-tier) |
| Number of Contacts | Up to 20 per category; 14 seeded locally |
| Offline Functionality | Full 3-tier fallback + `/sync/offline-data` |
| Innovation | YOLOv8 AI triage + `service_feedback` + `app_logs` |
| Global Coverage | 11 countries emergency numbers + OSM worldwide |

---

*RoadSOS — Making roads safer, one response at a time.*
