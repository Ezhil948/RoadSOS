[SYSTEM DIRECTIVES FOR AI]
CRITICAL INSTRUCTION FOR AI AGENTS: You must read this entire file before suggesting changes. At the end of every major task, file creation, or architectural change, you MUST autonomously update this MEMORY.md file to reflect the new state of the project. Do not wait for the user to ask you to update it.
APK GENERATION RULE: NEVER autonomously build or generate new APKs unless the user explicitly requests one. CRITICAL RULE: NEVER PREEMPTIVELY MENTION THAT A NEW APK IS REQUIRED. Do not say "this will require a new APK" in your plans or responses. ONLY discuss APK requirements if the user EXPLICITLY asks you to build an APK. The user has more work to do, and mentioning APKs forces them to reply and slow down. NEVER MENTION APKS UNLESS ASKED.

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
- **Repository Cleanup**: The unused E-commerce UI template folder has been completely moved out of the project repository to a backup location. The legacy `flutter_app/` (v1) was completely removed to avoid confusion with `flutter_app_v2`.
### 4.4 Operational Edge Case Overhaul
- **Manual Dispatch Fallback**: Unaccepted alerts after 60s are flagged for manual dispatch and displayed prominently on the Admin Dashboard.
- **Structured Officer Resolution**: Officers are required to categorize the incident upon resolution in the Officer App, and this is persisted and visible on the dashboard.
- **Spam Prevention & Grace Periods**: A strict 5-minute cooldown is enforced for citizens after raising an alert. However, a 15-second grace period is provided allowing the citizen to cancel an alert as a "false alarm" without penalty.
- **Real-time False Alarm Notifications**: Officer apps intercept `ALERT_CANCELLED_FALSE_ALARM` websocket events and automatically dismiss active dispatch screens with a false alarm dialog, avoiding unnecessary travel.
- **v4.4 APKs**: Optimized ARM64 release builds for both the Citizen App (`citizen_app_4.4_arm64.apk`) and Police/Officer App (`police_app_4.4_arm64.apk`) have been generated and saved to `apk/4.4/`.

## 5. Work In Progress & Next Steps
- **End-to-End Testing**: Proceed with end-to-end integration testing across the production environment for all scenarios (multi-officer dispatch, concurrent accident reporting, and dashboard synchronization).
- **Production Deployment Readiness**: Prepare the ecosystem for live usage, which includes final environment variable configuration.
