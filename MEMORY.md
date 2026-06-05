[SYSTEM DIRECTIVES FOR AI]
CRITICAL INSTRUCTION FOR AI AGENTS: You must read this entire file before suggesting changes. At the end of every major task, file creation, or architectural change, you MUST autonomously update this MEMORY.md file to reflect the new state of the project. Do not wait for the user to ask you to update it.
APK GENERATION RULE: NEVER autonomously build or generate new APKs unless the user explicitly requests one. CRITICAL RULE: NEVER PREEMPTIVELY MENTION THAT A NEW APK IS REQUIRED. Do not say "this will require a new APK" in your plans or responses. ONLY discuss APK requirements if the user EXPLICITLY asks you to build an APK. The user has more work to do, and mentioning APKs forces them to reply and slow down. NEVER MENTION APKS UNLESS ASKED.
APK VERSIONING RULE: When generating new APK versions, always create a new directory named after the version (e.g., `apk/4.5/`) inside the `apk` folder and save the compiled APKs there.

## 1. Project Overview
RoadSOS is an enterprise-grade emergency dispatch and tracking platform. It consists of four integrated applications that allow citizens to trigger SOS alerts, police officers to receive and accept dispatches in real-time, and dispatchers to monitor the entire city via a web dashboard.

## 2. Tech Stack & Dependencies
- **Backend Server**: Python, FastAPI, SQLAlchemy, MySQL, Uvicorn (Handles API routing and SQL math)
- **Citizen Mobile App**: Flutter, Dart, Provider (State), Hive (Local DB)
- **Officer Mobile App**: Flutter, Dart, Provider (State), AudioPlayers (Siren hardware)
- **Admin Dashboard Web App**: React, JavaScript, CSS

## 3. Architecture & File Structure
All four applications have been recently migrated to **Clean Architecture (Domain-Driven Design)** to ensure massive scalability.

```text
RoadSOS/
├── backend/                  # FastAPI Server
│   └── app/
│       ├── presentation/     # Thin HTTP endpoints (formerly routers)
│       ├── domain/           # Business Logic (e.g., sos_usecase.py handles cooldowns)
│       ├── data/             # Database Layer (e.g., sos_repository.py handles raw SQL)
│       └── utils/            # Utilities (e.g., websocket_manager.py)
│
├── flutter_app_v2/           # Citizen Mobile App
│   └── lib/features/emergency/
│       ├── data/             # Repositories (emergency_repository_impl.dart manages API/Hive)
│       ├── domain/           # UseCases (send_sos_usecase.dart handles offline SMS logic)
│       └── presentation/     # UI State (emergency_provider.dart manages 5s polling timers)
│
├── officer_mobile_app/       # Police Officer App
│   └── lib/features/dispatch/
│       └── dispatch_provider.dart # UI State & centralized dispatch logic
│
└── admin_dashboard/          # Headquarters Web Dashboard
    └── src/
        ├── components/       # Organized into layout/, overlays/, and widgets/
        ├── data/             # Repositories (DashboardRepositoryImpl.js handles fetch calls)
        ├── domain/           # UseCases (FetchDashboardDataUseCase.js sorts active vs past alerts)
        └── presentation/     # Custom Hooks (useDashboardData.js manages polling loops)
```

## 4. Current State (What Works)
- **Database Optimization**: Heavy O(N) memory bottlenecks have been completely eliminated. Geo-spatial Haversine distance sorting is now performed instantly at the MySQL database layer using `func.acos`.
- **Backend Clean Architecture**: The massive "Fat Controllers" for the `SOS`, `Dispatch`, `Auth`, and `Accident Reports` modules have been successfully broken down into Data Repositories and Domain Use Cases. The presentation layer was properly renamed from `routers/` to `presentation/`. WebSocket capabilities (`websocket_manager.py`) have also been added.
- **Frontend/Mobile Clean Architecture**: The complex state loops (e.g., polling timers, hardware sirens, offline SMS fallbacks) have been successfully decoupled from the UI widgets in the Citizen App, Officer App, and React Dashboard. In the Officer App, the dispatch module was simplified by removing redundant clean architecture boilerplate to centralize logic.
- **Admin Dashboard Overhaul**: The HQ Admin Dashboard has been completely rebuilt following the "Dark Ops Command Center" UX/UI Blueprint. It features a premium, responsive glassmorphic design using custom CSS variables (tokens.css) without Tailwind, complete with real-time mapping, alerts list, and data polling loops. Components were cleanly reorganized into `layout/`, `overlays/`, and `widgets/`.
- **Officer App UI Revamp**: The Officer Mobile App has received a major aesthetic overhaul, including a premium glassmorphic login screen, completely redesigned custom shields/badges, an updated Splash Screen, and a much cleaner, compact Home Duty layout.
- **Uber-style Dispatch System**: The continuous scanning dispatch loop is fully operational. It continuously scans for 5 minutes for new active officers if none are initially available.
- **Bug Fixes**: 
  - Backend schema auto-migrations implemented for missing `pinged_officer_ids` and `rejected_officer_ids` columns.
  - Citizen App SOS cancellation UI race condition fixed.
  - Officer App dispatch rejection SQL JSON mutation bug fixed (officers can now successfully dismiss dispatches).
  - Backend dispatch silent failures fixed by gracefully flagging missing GPS alerts for manual dispatch.
  - Admin Dashboard UI bug fixed where incidents incorrectly showed 'Location unavailable' due to a JSON key mismatch (`latitude`/`longitude` vs `lat`/`lng`).
  - Officer App WebSocket backgrounding bug fixed by implementing a robust HTTP fallback polling loop (`_fetchDispatch()`) to ensure dispatches are received even if the OS suspends the app when running alongside the Citizen App on the same device.
  - Admin Dashboard card glow and white-on-hover effect removed by stripping `box-shadow`, `animation`, and `::before` radial gradient overlay from `LiveIncidentCard.css`.
  - Timestamp "5 hrs ago" timezone bug fixed — backend now appends `Z` to `alerted_at` so browsers correctly parse it as UTC instead of local IST time (which was 5.5 hrs off).
  - Police cancel alert was silently failing because the DB `status` column was a strict ENUM that did not include `cancelled_by_police` or `cancelled_by_citizen`. Fixed by migrating the column from `ENUM` to `VARCHAR(30)` on both the live Aiven DB and `main.py` startup migrations.
  - Dashboard UNASSIGNED badge showing even after officer accepted — fixed by adding `accepted_officer_id` to the `list_sos_alerts` API response and updating `LiveIncidentCard.jsx` to use `isDispatched = officerName || accepted_officer_id`.
- **Repository Cleanup**: The unused E-commerce UI template folder has been completely moved out of the project repository to a backup location. The legacy `flutter_app/` (v1) was completely removed to avoid confusion with `flutter_app_v2`.
- **Feature Deprecation**: The AI Accident Image Analysis feature (`/api/v1/ai/analyze`) and YOLOv8 integration have been completely removed from the backend, frontend (`flutter_app_v2`), and database schema (`ai_analysis_results` table dropped) per user request to streamline the application.
### 4.4 Operational Edge Case Overhaul
- **Manual Dispatch Fallback**: Unaccepted alerts after 60s are flagged for manual dispatch and displayed prominently on the Admin Dashboard.
- **Structured Officer Resolution**: Officers are required to categorize the incident upon resolution in the Officer App, and this is persisted and visible on the dashboard.
- **Spam Prevention & Grace Periods**: A strict 5-minute cooldown is enforced for citizens after raising an alert. However, a 15-second grace period is provided allowing the citizen to cancel an alert as a "false alarm" without penalty.
- **Real-time False Alarm Notifications**: Officer apps intercept `ALERT_CANCELLED_FALSE_ALARM` websocket events and automatically dismiss active dispatch screens with a false alarm dialog, avoiding unnecessary travel.
- **v4.4 APKs**: Optimized ARM64 release builds for both the Citizen App (`citizen_app_4.4_arm64.apk`) and Police/Officer App (`police_app_4.4_arm64.apk`) have been generated and saved to `apk/4.4/`. The Police App APK was rebuilt after the WebSocket backgrounding fix.

### 4.5 SOS Resolution & UX Overhaul
- **Officer App (`main_map_screen.dart`)**: Single cancel button replaced with distinct **MARK CLEAR** and **STAND DOWN** buttons, backed by new bottom sheets for selecting category/notes or reasons (False Alarm vs Cannot Respond).
- **Citizen App (`sos_button.dart`)**: Polling handles granular states (`resolved`, `false_alarm`, `cancelled_by_police`) and presents a rich `DraggableScrollableSheet` with officer info, resolution details, and context. Reporter identity is properly passed to the API.
- **Admin Dashboard (`IncidentModal.jsx`)**: Shows False Alarm banners, Stand Down reasons, and enriched resolution sections.
- **Backend (`sos_usecase.py`)**: `get_alert_status()` now provides full officer/resolution metadata even after case closure.

## 5. Pre-Production Security & Performance Audit (v5.0)

A 27-finding audit was conducted across all four applications. **22 of 27 fixes have been implemented.**

### 5.1 COMPLETED — Critical Security Fixes (Backend)

| # | Finding | Files Modified |
|---|---------|----------------|
| #1 | **JWT Authentication** — Full token-based auth. Login now returns `access_token`. All officer endpoints require `Bearer` token. | `security.py` (rewritten), `auth_usecase.py` (rewritten), `auth.py` (rewritten), `requirements.txt` (+PyJWT) |
| #2 | **Officer Identity Spoofing** — All dispatch endpoints verify JWT `sub` claim matches URL `officer_id`. | `dispatch.py` (rewritten — all 5 endpoints have `Depends(get_current_officer)` + ID check) |
| #3 | **WebSocket Auth Bypass** — WebSocket verifies JWT token query param BEFORE accepting connection. | `dispatch.py` (WS endpoint), `api_endpoints.dart` (passes token), `dispatch_provider.dart` (sends token) |
| #4 | **Committed Secrets** — Removed hardcoded DB password default, added JWT_SECRET env var. | `database.py` (rewritten), `.env` (updated with JWT_SECRET, CORS_ORIGINS) |
| #5 | **CORS Wildcard** — `allow_origins=["*"]` replaced with env-based `CORS_ORIGINS`. | `main.py` (rewritten) |
| #6 | **SSL CERT_NONE** — Removed `check_hostname=False` and `verify_mode=ssl.CERT_NONE`. Uses CA cert or system bundle. | `database.py` (rewritten) |
| #7 | **Password Backdoor** — Null password_hash now returns `False`, not a match against literal `"password"`. | `security.py` (rewritten) |

### 5.2 COMPLETED — High Severity Fixes (Backend)

| # | Finding | Files Modified |
|---|---------|----------------|
| #8 | **SOS Rate Limiting** — 3 alerts per 10 minutes per IP, separate from general rate limit. | `main.py` (new `sos_requests` dict) |
| #9 | **Rate Limiter Memory Leak** — Periodic cleanup task prunes stale IPs every 5 minutes. | `main.py` (`_periodic_cleanup` coroutine) |
| #11 | **Category Validation** — Allowlist of 11 valid categories. Notes truncated to 1000 chars. | `sos_usecase.py` (`VALID_CATEGORIES` set) |
| #12 | **Fire-and-Forget WebSocket** — All `asyncio.create_task(manager.send_personal_message(...))` replaced with `await` + try/except. | `sos_usecase.py`, `dispatch_usecase.py` (both rewritten) |
| #13 | **Status Enum Crash** — `SOSAlert.status` changed from `Enum(AlertStatusEnum)` to `String(30)`. | `db_models.py` |
| #14 | **Cancel Race Condition** — `cancel_sos_alert()` now uses `get_alert_with_lock()` (SELECT FOR UPDATE). | `sos_repository.py` (new method), `sos_usecase.py` |
| #20 | **Officer Composite Index** — `idx_officer_dispatch_lookup(status, latitude, longitude)` added. | `db_models.py` (`__table_args__`), `main.py` (migration) |
| #24 | **Datetime UTC** — `to_utc_iso()` helper applied to all datetime serialization. | `sos_usecase.py`, `accident_usecase.py` |
| #26 | **Timeout Cleanup** — Moved from per-poll to background task running every 30s. | `main.py` (`_alert_cleanup_loop`) |

### 5.3 COMPLETED — Flutter App Fixes

| # | Finding | Files Modified |
|---|---------|----------------|
| #15 | **Citizen PII Storage** — SharedPreferences → FlutterSecureStorage (AES-256 via Android Keystore / iOS Keychain) | `pubspec.yaml` (+flutter_secure_storage), `auth_service.dart` (rewritten) |
| #16 | **Officer Token Storage** — Hive → FlutterSecureStorage for JWT. QueuedInterceptorsWrapper for async reads. | `pubspec.yaml` (+flutter_secure_storage), `api_client.dart` (rewritten), `login_screen.dart` (+saveAccessToken), `profile_screen.dart` (+clearAccessToken), `dispatch_provider.dart` (getAccessToken for WS) |
| #17 | **Hive.openBox → Hive.box** — Eliminated redundant disk I/O on every 5s poll. 8 occurrences fixed. | `sos_button.dart`, `emergency_repository_impl.dart`, `api_service.dart` |
| #18 | **Duplicate Polling** — HTTP poll only runs when WebSocket is disconnected (`_wsAlive` flag). | `dispatch_provider.dart` |
| #19 | **Siren Stop** — `_audioPlayer.stop()` added in 7 cancel/reject/miss/false-alarm paths. | `dispatch_provider.dart` |

### 5.4 COMPLETED — Admin Dashboard Fixes

| # | Finding | Files Modified |
|---|---------|----------------|
| #10 | **Dashboard Auth Gate** — Login screen blocks access. Token sent as Bearer header. Auto-logout on 401. Logout button in TopCommandBar. | `AdminLogin.jsx` (new), `App.jsx` (rewritten), `api.js` (rewritten), `TopCommandBar.jsx` (+onLogout+LogOut icon) |
| #21 | **isDispatched Truthiness** — Explicit `null`/`undefined`/`""` checks instead of loose `||`. | `LiveIncidentCard.jsx` |
| #22 | **Re-render Optimization** — `JSON.stringify` equality check prevents state update on unchanged data. | `useDashboardData.js` |
| #25 | **Error Boundary** — Wraps MainCanvas and AlertFeed. Crash shows retry button instead of white screen. | `ErrorBoundary.jsx` (new), `App.jsx` |

### 5.5 DEFERRED — Not Implementing Now

| # | Finding | Risk | Reason |
|---|---------|------|--------|
| #23 | **SOS Button State Dedup** — 800-line widget duplicates EmergencyProvider logic | Low | Major refactor of working code. No security or correctness impact. |
| #27 | **Hardcoded API URL** — Use `--dart-define` compile-time flag | Low | URL is already public-facing. No security impact. |

### 5.6 Audit Score: **25 of 27 findings fixed (93%)**
- **7/7 CRITICAL** — All resolved
- **8/8 HIGH (Backend)** — All resolved
- **5/5 HIGH (Flutter)** — All resolved
- **4/4 MEDIUM (Dashboard)** — All resolved
- **1/1 MEDIUM (Backend)** — Resolved
- **2/2 LOW** — Intentionally deferred

## 6. Work In Progress & Next Steps
- **Secret Rotation**: Rotate the IMGBB API key and DB password (current ones are burned from git history).
- **Production .env**: Set real `JWT_SECRET`, `CORS_ORIGINS`, `DB_CA_CERT_PATH` for Render deployment.
- **Create admin officer**: Insert an officer record with badge_number='admin' and a real password hash for dashboard login.
- **End-to-End Testing**: Full integration test of JWT auth flow (login → token → dispatch → resolve).

