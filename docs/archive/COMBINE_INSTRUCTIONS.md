# Instructions for Gemini Pro: Codebase Merging & Integration Guide

## 🎯 Goal
Combine the **Workspace Root code** (the baseline, containing Hive caching, SMS fallback, and international geocoding) with **Kisanth's code** (located in `file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/kisanths_model/`, containing user authentication and background offline-syncing) to produce the next optimized version of RoadSOS.

---

## 🛠️ Step-by-Step Integration Plan

### Step 1: Update Dependencies
*   **File to edit**: [flutter_app_v2/pubspec.yaml](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/pubspec.yaml)
*   **Action**: Merge dependencies from both pubspecs. Ensure the following are present:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      dio: ^5.9.2
      flutter_map: ^8.3.0
      geolocator: ^14.0.2
      google_fonts: ^8.1.0
      image_picker: ^1.2.2
      latlong2: ^0.9.1
      permission_handler: ^12.0.1
      provider: ^6.1.5+1
      url_launcher: ^6.3.2
      shared_preferences: ^2.2.3
      path_provider: ^2.1.5
      connectivity_plus: ^6.0.3  # Add from Kisanth's code
      hive: ^2.2.3                # Keep from Workspace
      hive_flutter: ^1.1.0        # Keep from Workspace
    ```
*   **Version Code**: Increment to `0.1.2+3`.

---

### Step 2: Copy Authentication & Offline Sync Core Files
Copy the following files from `/kisanths_model` to the active project directories:
1.  **Auth Features**: Copy directory `/kisanths_model/flutter_app_v2/lib/features/auth/` to [flutter_app_v2/lib/features/auth/](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/features/auth/).
2.  **Auth Service**: Copy file `/kisanths_model/flutter_app_v2/lib/services/auth_service.dart` to [flutter_app_v2/lib/services/auth_service.dart](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/services/auth_service.dart).
3.  **Offline Sync Service**: Copy file `/kisanths_model/flutter_app_v2/lib/services/offline_sync_service.dart` to [flutter_app_v2/lib/services/offline_sync_service.dart](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/services/offline_sync_service.dart).
4.  **Offline Report Model**: Copy file `/kisanths_model/flutter_app_v2/lib/models/offline_report.dart` to [flutter_app_v2/lib/models/offline_report.dart](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/models/offline_report.dart).

---

### Step 3: Wire Up Services in `main.dart`
*   **File to edit**: [flutter_app_v2/lib/main.dart](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/main.dart)
*   **Action**:
    1.  Ensure `LocalCacheService.init()` is called and awaited (needed for Hive).
    2.  Add `AuthService` and `OfflineSyncService` to the `MultiProvider` block:
        ```dart
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(
          create: (context) => OfflineSyncService(
            apiService: context.read<ApiService>(),
          ),
        ),
        ```
    3.  Set the initial route/home widget of `MaterialApp` to `const SplashScreen()` from the `auth` feature package, enabling the animated launch check.

---

### Step 4: Merge UI Elements & Features

#### 1. Accident Reporting Screen (`report_screen.dart`)
*   **File to edit**: [flutter_app_v2/lib/features/emergency/report_screen.dart](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/features/emergency/report_screen.dart)
*   **Action**: Keep the Workspace's robust exception handling (e.g. model offline fallback), but if submission fails due to network (e.g. `DioException`, `SocketException`), catch it and invoke:
    ```dart
    context.read<OfflineSyncService>().saveReportOffline(...);
    ```

#### 2. Emergency Overview Tab (`emergency_tab.dart`)
*   **File to edit**: [flutter_app_v2/lib/features/emergency/emergency_tab.dart](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/features/emergency/emergency_tab.dart)
*   **Action**:
    1.  Insert the logout icon/button in the header, calling `AuthService.logout()` and navigating to `LoginScreen`.
    2.  Insert `_buildOfflineSyncCard(context)` from Kisanth's emergency tab directly above the location status card.
    3.  Keep the large "File Accident Report" button layout and the updated SMS fallback configuration on the SOS button.

#### 3. Helplines Tab (`helplines_tab.dart`)
*   **File to edit**: [flutter_app_v2/lib/features/helplines/helplines_tab.dart](file:///c:/Users/ezhil/OneDrive/Desktop/RoadSOS/RoadSOS/flutter_app_v2/lib/features/helplines/helplines_tab.dart)
*   **Action**: Keep the Workspace's country geocoding routing and Hive cache loading. Above the dynamic helplines category grid, insert Kisanth's **"Nearby Hospitals" summary card panel**, which displays the 3 closest emergency care facilities using OSM/Overpass.

---

## 🧪 Verification & Build
1.  Run `flutter pub get` in `flutter_app_v2/` to update project packages.
2.  Test the compilation for Web/Android.
3.  Simulate offline mode (disable WiFi/Cellular or toggle airplane mode) and verify:
    *   SOS triggers the SMS fallback (`112`).
    *   Reporting an accident with an image saves it locally, displays the sync banner, and automatically pushes the report to Render upon network reconnection.
    *   Helplines tab successfully falls back to Hive-cached numbers and shows geocoded cards.
