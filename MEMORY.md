[SYSTEM DIRECTIVES FOR AI]
CRITICAL INSTRUCTION FOR AI AGENTS: You must read this entire file before suggesting changes. At the end of every major task, file creation, or architectural change, you MUST autonomously update this MEMORY.md file to reflect the new state of the project. Do not wait for the user to ask you to update it.
APK GENERATION RULE: NEVER autonomously build or generate new APKs unless the user explicitly requests one. Even if the user requests an APK, if there are no frontend codebase changes that strictly require a new client-side app installation (e.g., only backend logic changed), you must explain why a new APK is unnecessary and refrain from building it.

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
│       ├── routers/          # Presentation Layer (Thin HTTP endpoints like sos.py)
│       ├── domain/           # Business Logic (e.g., sos_usecase.py handles cooldowns)
│       └── data/             # Database Layer (e.g., sos_repository.py handles raw SQL)
│
├── flutter_app_v2/           # Citizen Mobile App
│   └── lib/features/emergency/
│       ├── data/             # Repositories (emergency_repository_impl.dart manages API/Hive)
│       ├── domain/           # UseCases (send_sos_usecase.dart handles offline SMS logic)
│       └── presentation/     # UI State (emergency_provider.dart manages 5s polling timers)
│
├── officer_mobile_app/       # Police Officer App
│   └── lib/features/dispatch/
│       ├── data/             # Repositories (dispatch_repository_impl.dart manages siren audio)
│       ├── domain/           # UseCases (respond_dispatch_usecase.dart)
│       └── presentation/     # UI State (dispatch_provider.dart manages incoming alert state)
│
└── admin_dashboard/          # Headquarters Web Dashboard
    └── src/
        ├── data/             # Repositories (DashboardRepositoryImpl.js handles fetch calls)
        ├── domain/           # UseCases (FetchDashboardDataUseCase.js sorts active vs past alerts)
        └── presentation/     # Custom Hooks (useDashboardData.js manages polling loops)
```

## 4. Current State (What Works)
- **Database Optimization**: Heavy O(N) memory bottlenecks have been completely eliminated. Geo-spatial Haversine distance sorting is now performed instantly at the MySQL database layer using `func.acos`.
- **Backend Clean Architecture**: The massive "Fat Controllers" for the `SOS`, `Dispatch`, `Auth`, and `Accident Reports` modules have been successfully broken down into Data Repositories and Domain Use Cases.
- **Frontend/Mobile Clean Architecture**: The complex state loops (e.g., polling timers, hardware sirens, offline SMS fallbacks) have been successfully decoupled from the UI widgets in the Citizen App, Officer App, and React Dashboard.
- **Production Deployment**: All local backend Clean Architecture code has been pushed to `main` and is actively deploying to the Render production server (`roadsos-backend-htmk.onrender.com`). Both Flutter apps have been reverted to point back to the production API.

## 5. Work In Progress & Next Steps
- **Wait for Render Deployment**: Once Render finishes building the new backend, the `v4.1` APKs (which point to production) should instantly start receiving SOS dispatches natively using the new `DispatchUseCase` logic.
- **Next Feature**: Build out the React Admin Dashboard vertical slice or proceed with end-to-end integration testing across the production environment.
