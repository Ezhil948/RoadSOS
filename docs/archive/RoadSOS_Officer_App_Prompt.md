# RoadSOS Officer Mobile App — Complete Build Prompt for Gemini

> **Purpose of this document:** Hand this entire file to Gemini as the prompt. It is a complete product specification, design system, screen inventory, state machine, backend contract, and implementation plan. Every section should be treated as a hard requirement unless explicitly labelled *optional*.

---

## 0. Meta-Instructions for Gemini

You are building a production-grade Flutter mobile application for police officers. This is **not a prototype** — every screen must be fully implemented with real logic, real state management (use Riverpod), real API calls, real animations, and real error handling. Do not use placeholder widgets or `// TODO` comments. Do not build only the dispatch screen and skip the rest. Every screen described in Section 4 must exist as a navigable route.

Read this entire document before writing a single line of code.

---

## 1. Identity & Vision

**App name:** RoadSOS Officer  
**Platform:** Flutter (iOS + Android)  
**State management:** Riverpod (use `StateNotifierProvider` and `AsyncNotifierProvider`)  
**Navigation:** GoRouter with shell routes (persistent bottom nav)  
**HTTP client:** Dio with an interceptor that injects bearer tokens  
**Local persistence:** Hive for cached officer profile, theme preference, notification history  
**Fonts:** `JetBrains Mono` for all monospaced/data elements (badge numbers, distances, times, coordinates, alert IDs). `Inter` for body text. Both loaded via `google_fonts`.

**The aesthetic:** Think of a senior engineer's personal terminal — git CLI meets modern mobile design. Dark green on near-black, crisp typography, status badges that look like git branch labels, clean dividers, no gradients, no glassmorphism. On the light theme, think GitHub's light mode: warm white surfaces, subtle borders, green accent. Everything feels precise, reliable, deliberate. No rounded blobs. No playful animations. Purposeful micro-interactions only.

---

## 2. Design System — Implement as a Single `app_theme.dart`

### 2.1 Color Tokens

```dart
// ── DARK THEME (default) ──────────────────────────────────────────────
const kDarkBg         = Color(0xFF0D1117);  // GitHub dark canvas
const kDarkSurface    = Color(0xFF161B22);  // card/sheet surface
const kDarkBorder     = Color(0xFF30363D);  // dividers, outlines
const kDarkMuted      = Color(0xFF484F58);  // placeholder text, icons at rest
const kDarkText       = Color(0xFFE6EDF3);  // primary text
const kDarkSubtext    = Color(0xFF8B949E);  // secondary text, labels
const kAccentGreen    = Color(0xFF3FB950);  // primary action, online, success
const kAccentGreenDim = Color(0xFF238636);  // pressed state, secondary
const kAccentRed      = Color(0xFFF85149);  // alerts, danger, false alarm
const kAccentAmber    = Color(0xFFD29922);  // warnings, medium severity
const kAccentBlue     = Color(0xFF58A6FF);  // info, links, "call" action
const kBadgeBg        = Color(0xFF21262D);  // git badge pill background

// ── LIGHT THEME ───────────────────────────────────────────────────────
const kLightBg        = Color(0xFFFFFFFF);
const kLightSurface   = Color(0xFFF6F8FA);
const kLightBorder    = Color(0xFFD0D7DE);
const kLightMuted     = Color(0xFF636C76);
const kLightText      = Color(0xFF1F2328);
const kLightSubtext   = Color(0xFF656D76);
// Accent colors remain identical across both themes.
```

### 2.2 Typography Scale

```dart
// All sizes in sp. Use JetBrainsMono for anything that is a number, ID, or code.
// headline1  — 28sp, Inter 700 — Screen titles
// headline2  — 22sp, Inter 600 — Section headers
// body1      — 15sp, Inter 400 — Main body copy
// body2      — 13sp, Inter 400 — Secondary descriptions
// label      — 12sp, Inter 500 — Labels, form field titles
// mono_lg    — 20sp, JetBrainsMono 700 — ETA, distance, big data numbers
// mono_md    — 15sp, JetBrainsMono 500 — Badge numbers, IDs, coordinates
// mono_sm    — 12sp, JetBrainsMono 400 — Timestamps, log entries
```

### 2.3 Spacing & Shape System

- Base unit: `8dp`. Use multiples (4, 8, 12, 16, 24, 32, 48).
- Border radius: Cards → `8dp`. Buttons → `6dp`. Badges → `4dp`. Input fields → `6dp`. FABs → `12dp`.
- Card elevation: `0` (borders only, no shadows). Use `Container` with `BoxDecoration(border: Border.all(...))`.
- Dividers: `0.5dp` height, `kDarkBorder` color.

### 2.4 Component Library — Build these as reusable widgets

**`GitBadge`** — pill-shaped label, left icon + text:
```
[● online]   — green dot + green text on kBadgeBg
[⚠ high]     — amber triangle + amber text
[✕ offline]  — red × + muted text
[→ busy]     — blue arrow + blue text
```

**`StatRow`** — icon + label + value in a horizontal row, separated by dotted line fill:
```
⏱  Response time .......... 4m 12s
📍 Shift distance ......... 23.4 km
```

**`SectionHeader`** — monospace label in uppercase, full-width border underneath:
```
// ACTIVE DISPATCH ──────────────────────────────────
```

**`AlertCard`** — compact card with severity stripe on the left edge (red/amber/green), alert ID in monospace top-right, message body, distance + ETA in mono font.

**`PrimaryButton`** — full-width, solid `kAccentGreen` fill, white text, 48dp height. Pressed: scale 0.97, slight darken.

**`DangerButton`** — same but `kAccentRed`.

**`OutlinedButton`** — transparent fill, `kDarkBorder` border. For secondary actions.

**`SlideToConfirm`** — horizontal track, draggable thumb with arrow icon. Completes only when thumb reaches end (>90% of track width). Has spring-back animation if released early. Label text fades out as thumb progresses. Haptic feedback on completion (`HapticFeedback.heavyImpact()`).

**`MonoMetric`** — large JetBrainsMono number + small unit label below + optional icon above. Used for ETA, distance, severity.

---

## 3. App Architecture

### 3.1 File Structure

```
lib/
├── main.dart
├── app.dart                    # MaterialApp, theme switching, GoRouter
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── theme_provider.dart  # Riverpod StateProvider<ThemeMode>
│   ├── network/
│   │   ├── api_client.dart      # Dio singleton with interceptors
│   │   └── api_endpoints.dart   # all URL constants
│   ├── services/
│   │   ├── location_service.dart
│   │   ├── notification_service.dart
│   │   └── haptic_service.dart
│   └── models/
│       ├── officer.dart
│       ├── dispatch.dart
│       ├── alert.dart
│       └── shift_stats.dart
├── features/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── auth_provider.dart
│   ├── home/
│   │   ├── home_screen.dart
│   │   └── home_provider.dart
│   ├── dispatch/
│   │   ├── dispatch_provider.dart
│   │   ├── incoming_alert_screen.dart
│   │   ├── navigation_screen.dart   # MAP IS HERE ONLY
│   │   └── resolution_screen.dart
│   ├── history/
│   │   ├── history_screen.dart
│   │   └── history_provider.dart
│   ├── profile/
│   │   ├── profile_screen.dart
│   │   └── profile_provider.dart
│   ├── leaderboard/
│   │   └── leaderboard_screen.dart
│   ├── notifications/
│   │   └── notifications_screen.dart
│   └── settings/
│       └── settings_screen.dart
└── widgets/                     # All shared components from Section 2.4
```

### 3.2 Navigation Structure

Use **GoRouter** with a `StatefulShellRoute` for the bottom navigation bar. The shell persists across tab switches.

**Bottom Nav Tabs (5 items, icon + label):**
1. `Home` — `Icons.terminal_rounded`
2. `History` — `Icons.history`
3. `Leaderboard` — `Icons.leaderboard_outlined`
4. `Notifications` — `Icons.notifications_outlined` (badge count)
5. `Profile` — `Icons.person_outline`

**Modal/full-screen routes (no bottom nav):**
- `/login`
- `/dispatch/incoming` — pushed on top of shell when dispatch arrives
- `/dispatch/navigate` — **map lives here**
- `/dispatch/resolve`
- `/settings` — pushed from profile tab

### 3.3 State Machine

Implement `OfficerStatus` as a sealed class:

```dart
sealed class OfficerStatus {}
class Offline extends OfficerStatus {}
class Online extends OfficerStatus {}      // scanning, no dispatch
class Dispatching extends OfficerStatus {  // overlay shown
  final DispatchModel dispatch;
}
class Navigating extends OfficerStatus {   // map visible
  final DispatchModel dispatch;
}
class Arrived extends OfficerStatus {      // resolve/false alarm
  final DispatchModel dispatch;
}
```

The `DispatchNotifier` (Riverpod `StateNotifier<OfficerStatus>`) drives all state transitions. Every status change that requires a screen change uses GoRouter's `ref.read(routerProvider).go(...)`.

---

## 4. Screen-by-Screen Specification

> The **MAP** (flutter_map + OpenStreetMap tiles) appears **only** in the `NavigationScreen`. It must **not** appear on any other screen. The home screen is a data dashboard, not a map.

---

### 4.1 Login Screen — `/login`

**Purpose:** Authenticate officer before any API calls.

**Layout:**
- Top 35% of screen: dark surface with the RoadSOS badge — a `JetBrainsMono` monogram "RS" in a hexagon border, and below it the text `$ roadsos --officer-mode` in green.
- Bottom 65%: white/surface card rising up (use `DraggableScrollableSheet` or just a rounded-top container).
  
**Fields:**
- Badge Number (keyboard: number, `mono_md` font in field)
- Password (obscured, toggle visibility)
- Server URL field (optional, collapsed by default under "Advanced ▼" — expands to reveal the URL field with a prefilled default)

**Actions:**
- `[ LOG IN ]` — primary green button. Shows circular progress inside the button while loading (replace text with `SizedBox` + `CircularProgressIndicator`).
- On success: navigate to `/` (home shell).
- On error: show inline error below the badge field, shake the form with `AnimationController`.

**Extras:**
- "Remember me" toggle (persists session token in Hive).
- Version string in `mono_sm` at the very bottom: `v1.4.2 · build 88`.
- Biometric login button (fingerprint icon) if a saved session exists.

---

### 4.2 Home Screen — `/` (Tab 1)

**This is the operational hub. No map. Think a CLI dashboard.**

**Top Section — Status Bar:**
```
┌─────────────────────────────────────────────────┐
│  SGT. RAJAN KUMAR          [● online]           │
│  Badge #4821               Shift: 06:00 – 18:00 │
└─────────────────────────────────────────────────┘
```
The `[● online]` / `[✕ offline]` is a tappable `GitBadge` that triggers the Go Online / Go Offline flow (with confirmation bottom sheet).

**Go Online / Go Offline flow:**
- Tapping the badge opens a `ModalBottomSheet` (not a full-screen dialog).
- If offline → shows "Go Online?" sheet with a green `[ CONFIRM: GO ONLINE ]` button and location permission check.
- If online → shows "End patrol?" sheet with reason dropdown: `[ End of Shift | Break | Equipment Issue | Other ]` + `[ CONFIRM OFFLINE ]`.
- Do NOT use a big pulsing button on the home screen. The badge pill IS the control.

**Middle Section — Today's Shift Stats:**

Use a 2×3 `GridView` of `MonoMetric` cards:
```
[ 04 ]           [ 2.3 km ]        [ 12m 34s ]
 Dispatches       Avg Distance      Avg Response

[ 00 ]           [ 4.92 ★ ]        [ 08:41 ]
 False Alarms     Rating            Time Online
```

**Lower Section — Activity Feed:**

A `ListView` of recent events in this shift, styled like a git log:

```
// SHIFT ACTIVITY ──────────────────────────────────
  
  ● 10:42  Dispatch #88 resolved          [✓ closed]
  │        Accident near MG Road · 1.2 km
  
  ● 09:31  Dispatch #85 rejected          [→ passed]
  │        SOS at Brigade Road · busy status
  
  ● 08:41  Patrol started                 [▶ online]
  │        Location: 12.9716°N 77.5946°E
```
Each row is tappable → pushes to the `HistoryDetailScreen` for that alert.

**Floating Action Area (bottom of home screen, above bottom nav):**

A slim horizontal bar (not a FAB) with two actions:
- `[⊕ Report Incident]` — opens a quick incident report sheet
- `[📍 Share Location]` — opens a share sheet with current coordinates

---

### 4.3 Incoming Alert Screen — pushed modally, full-screen

**Triggered:** when `dispatch.has_dispatch == true` from the polling loop. Push this route on top of everything using `GoRouter.of(context).push('/dispatch/incoming')`.

**DO NOT use a pulsing full-screen red overlay. Use this layout instead:**

**Top 15% — Alert Header:**
```
// INCOMING DISPATCH ─────────────────────────────
   ALERT #42                         [⚠ HIGH]
```
Red left-border strip along the entire screen's left edge (4dp wide, `kAccentRed`).

**Middle 55% — Metrics Panel:**

Three `MonoMetric` widgets in a row:
```
   05 MIN          1.25 KM         HIGH
   ETA             Distance        Severity
```
Below that, the alert message in a bordered card:
```
┌─ message ──────────────────────────────────────┐
│  Accident near main road, victim unconscious.  │
│  Reported by civilian user · 2 mins ago        │
└────────────────────────────────────────────────┘
```
Below that, a static mini-map preview (use `flutter_map` with a fixed, non-interactive viewport showing just the pin at the alert's coordinates — no panning, no tiles interaction). Size: 200dp height.

**Bottom 30% — Actions:**
```
[ TAP TO ACCEPT ]   — full-width, green, 56dp tall
[ REJECT ]          — full-width, outlined/danger, 40dp tall
```

**Countdown:** A thin linear progress bar at the very top of the screen counts down 30 seconds. If it reaches 0, auto-reject and pop the route.

**Sound + Haptics:** Play a short alert sound (use `audioplayers`) and trigger `HapticFeedback.heavyImpact()` on arrival.

---

### 4.4 Navigation Screen — `/dispatch/navigate` — **MAP IS HERE**

**This is the only screen with a map.**

**Map library:** `flutter_map` + `flutter_map_tile_caching` (for offline tile cache). Tile server: OpenStreetMap (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`).

**Layout (top-to-bottom stack):**

```
┌─────────────────────────────────────────────────┐
│  [← DISPATCH #42]    [📍 Re-center]             │  ← 56dp AppBar over map
├─────────────────────────────────────────────────┤
│                                                 │
│            MAP (fills remaining space)          │
│   - Officer location marker (blue dot, pulsing) │
│   - Alert destination marker (red pin)          │
│   - Polyline route between them (blue dashed)   │
│                                                 │
├─────────────────────────────────────────────────┤
│  VICTIM INFORMATION                    [📞 CALL]│
│  Name: [REDACTED]   Phone: +91 98XXXXXX82       │
│  Notes: Unconscious, breathing                  │
│  ────────────────────────────────────────────── │
│  [ SLIDE TO ARRIVE ─────────────────────── >> ] │
└─────────────────────────────────────────────────┘
```

**Map behaviors:**
- Auto-centers on officer's location every 5 seconds if re-centering is enabled.
- Tap `[📍 Re-center]` button to snap back.
- Show a `flutter_map` `Polyline` layer with the route. Fetch routing from OSRM (`http://router.project-osrm.org/route/v1/driving/{start};{end}?geometries=geojson`).
- Custom marker for the alert: red teardrop SVG. Custom marker for officer: blue pulsing circle using `AnimationController`.

**Bottom Sheet:**
- Persistent, non-dismissible `DraggableScrollableSheet` with `initialChildSize: 0.28`, `minChildSize: 0.18`, `maxChildSize: 0.45`.
- Contains victim info + the `SlideToConfirm` widget.
- Sliding up reveals more info (notes, address, timestamp).

**On slide complete:**
- Call `PATCH /api/v1/dispatch/officers/{id}/status` → `arrived`
- Push `/dispatch/resolve`

---

### 4.5 Resolution Screen — `/dispatch/resolve`

**No map. Clean decision screen.**

**Layout:**
```
// DISPATCH #42 — RESOLUTION ─────────────────────

   Arrived at: 10:47 AM
   Response time: 6m 23s            [▲ personal best!]

   What was the outcome?

   [ ✓ MARK RESOLVED ]     — full-width, green, 56dp
   
   ─── or ────────────────────────────────────────
   
   [ ✕ FLAG AS FALSE ALARM ]  — outlined, red

   Notes (optional):
   ┌──────────────────────────────────────────────┐
   │  Add notes about the incident...             │
   └──────────────────────────────────────────────┘
   
   [ SUBMIT ]
```

**On MARK RESOLVED:** Call `PATCH /api/v1/sos/alerts/{id}/resolve` → show success animation → pop to home tab.  
**On FALSE ALARM:** Show confirmation dialog: "This will penalize the civilian's trust score by 50 points. Are you sure?" → if confirmed, call `PATCH /api/v1/sos/alerts/{id}/false_alarm` → pop to home.

**Success animation:** A brief `Lottie` animation (use `lottie` package with a simple checkmark JSON file), then auto-navigate home after 1.5 seconds.

---

### 4.6 History Screen — `/history` (Tab 2)

**Shows all past dispatches for this officer.**

**Top Controls:**
- Search bar (filter by alert ID, date, location keyword)
- Filter chips: `[ All ] [ Resolved ] [ False Alarm ] [ Rejected ]`
- Sort: dropdown `▼ Newest first`

**List Layout:** Use `ListView.separated` with `AlertCard` widgets:
```
┌────────────────────────────────────────────────┐
│ [⚠ HIGH]  Alert #88          10:42 AM · Today  │
│ Accident near MG Road                           │
│ ── 1.2 km · 6m 23s response ── [✓ resolved]    │
└────────────────────────────────────────────────┘
```
Left edge colored stripe matches severity.

**Detail View (tap → push `HistoryDetailScreen`):**
- Full timeline of the dispatch lifecycle as a vertical stepper:
  ```
  ● 10:36  Dispatch received
  ● 10:37  Accepted by officer
  ● 10:40  Officer arrived
  ● 10:42  Marked as resolved
  ```
- Static map showing the incident location (non-interactive `flutter_map` tile with marker).
- Victim notes (if any).
- Officer notes submitted at resolution.

**Pagination:** Load 20 items at a time, infinite scroll with a `CircularProgressIndicator` footer loader.

---

### 4.7 Leaderboard Screen — `/leaderboard` (Tab 3)

**Shows officer rankings for the current month.**

**Top:**
```
// LEADERBOARD — MAY 2025 ─────────────────────────
   [▶ This Month]  [Station]  [District]       ← tab chips
```

**Top 3 Podium:**
A custom widget showing rank 1 (tallest), rank 2 (left), rank 3 (right) as vertical bars, like a finish podium. Each has a badge number label and response count.

**Full List:**
```
#04   SGT. RAJAN KUMAR              ●  12 dispatches
      Avg response: 5m 42s
      
#05   PC MEENA IYER                 ●  11 dispatches
      Avg response: 6m 01s
```
Current officer's row is highlighted with a left accent border in `kAccentGreen`.

**Metrics available:** toggleable between Dispatch Count, Avg Response Time, False Alarm Rate, Rating.

---

### 4.8 Notifications Screen — `/notifications` (Tab 4)

**Log of all system notifications.**

Grouped by date, same git-log style:

```
// TODAY ──────────────────────────────────────────

  [ℹ]  10:36  New dispatch assigned — Alert #88
  [✓]  10:42  Alert #88 resolved successfully
  [⚠]  09:15  Warning: GPS accuracy low

// YESTERDAY ───────────────────────────────────────

  [ℹ]  18:30  Shift ended — summary sent to station
```

Tapping a notification item navigates to the relevant detail screen (history detail if it's a dispatch notification).

**Unread count** shown as a badge on the tab icon.

---

### 4.9 Profile Screen — `/profile` (Tab 5)

**Layout:**

**Header Card:**
```
┌────────────────────────────────────────────────┐
│   [ RS ]   SGT. RAJAN KUMAR                    │
│   (hex)    Badge #4821 · Chennai Central       │
│            Joined: March 2021                  │
└────────────────────────────────────────────────┘
```
The `[ RS ]` is a hexagon avatar with the officer's initials.

**Stats Section:**
```
// CAREER STATS ──────────────────────────────────

  Total dispatches .......... 847
  Avg response time ......... 5m 14s
  Resolution rate ........... 94.2%
  Current rating ............ 4.92 ★
  False alarm flags ......... 3
```

**Shift History Graph:**
A 7-day bar chart using `fl_chart` showing dispatch count per day.

**Quick Links:**
- `[⚙ Settings]` → `/settings`
- `[📋 Incident Report History]` → history screen
- `[🔒 Change Password]` → modal
- `[↩ Log Out]` → clears Hive + navigates to `/login`

---

### 4.10 Settings Screen — `/settings`

**Sections:**

**Appearance:**
- Theme toggle: `[ ☀ Light ]  [ ◑ System ]  [ ● Dark ]` — segmented control
- Map style: `[ Standard ]  [ Satellite ]  [ High Contrast ]`

**Notifications:**
- Push alerts toggle
- Sound on incoming dispatch toggle
- Vibration toggle
- Alert sound selector: dropdown with 3 options

**Patrol:**
- Location ping interval: slider `[ 3s ── 10s ── 30s ]`
- Auto-go-offline after idle: dropdown `[ 30m | 1h | 2h | Never ]`
- Auto-reject dispatch after: slider `[ 15s | 30s | 45s ]`

**About:**
- App version, build, server URL (editable)
- `[Send Debug Logs]` — copies log dump to clipboard
- `[Open API Docs]` — launches browser

---

## 5. Dispatch Polling Engine — Implement as a Background Service

This is critical. Implement `DispatchPollingService` as a Riverpod provider that:

1. Starts when officer goes online.
2. Runs a `Timer.periodic(Duration(seconds: 3), ...)` loop.
3. Each tick: sends a location ping AND polls for dispatch.
4. If `has_dispatch == true` AND current status is not already `Dispatching/Navigating/Arrived`:
   - Transitions state to `Dispatching`
   - Navigates to `/dispatch/incoming` using GoRouter
   - Plays alert sound
   - Triggers haptic feedback
5. Stops immediately when officer goes offline.
6. Handles errors gracefully: on 3 consecutive failures, show a non-blocking snackbar "Connection issues — retrying..." and continue trying.
7. Cancels the `Timer` properly when the provider is disposed.

```dart
// Pseudo-structure
class DispatchPollingNotifier extends StateNotifier<OfficerStatus> {
  Timer? _timer;
  int _failCount = 0;

  void startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), _tick);
  }

  Future<void> _tick(Timer t) async {
    try {
      await _sendLocationPing();
      final dispatch = await _checkForDispatch();
      if (dispatch != null && state is Online) {
        state = Dispatching(dispatch);
        _router.push('/dispatch/incoming');
        _haptic.heavy();
        _sound.playAlert();
      }
      _failCount = 0;
    } catch (e) {
      _failCount++;
      if (_failCount >= 3) _showConnWarning();
    }
  }

  void stopPolling() => _timer?.cancel();
}
```

---

## 6. Backend API Contract

Base URL: configurable (saved in Settings → About → Server URL). Default: `http://localhost:8000`.

### 6.1 Authentication
```
POST /api/v1/auth/login
Body: { "badge_number": "4821", "password": "..." }
Response: { "access_token": "...", "officer": { ...OfficerModel } }
```
Store token in Hive. Add to every request via Dio interceptor: `Authorization: Bearer {token}`.

### 6.2 Location Ping
```
POST /api/v1/dispatch/officers/{officer_id}/ping
Body: { "latitude": 12.97, "longitude": 77.59, "status": "available" | "offline" | "busy" }
Response: 200 OK
```

### 6.3 Poll for Dispatch
```
GET /api/v1/dispatch/officers/{officer_id}/dispatch
Response (assigned): { "has_dispatch": true, "dispatch": { "alert_id": 42, "latitude": ..., "longitude": ..., "severity": "high", "distance_km": 1.25, "eta_mins": 2, "message": "..." } }
Response (none):     { "has_dispatch": false }
```

### 6.4 Accept / Reject
```
POST /api/v1/dispatch/officers/{officer_id}/dispatch/{alert_id}
Body: { "action": "accept" | "reject" }
Response: 200 OK
```

### 6.5 Resolve & False Alarm
```
PATCH /api/v1/sos/alerts/{alert_id}/resolve
PATCH /api/v1/sos/alerts/{alert_id}/false_alarm
Body: { "officer_notes": "..." }
Response: 200 OK
```

### 6.6 History
```
GET /api/v1/officers/{officer_id}/history?page=1&limit=20&status=resolved
Response: { "items": [...AlertModel], "total": 120, "page": 1 }
```

### 6.7 Profile & Stats
```
GET /api/v1/officers/{officer_id}/profile
GET /api/v1/officers/{officer_id}/stats?period=month
GET /api/v1/leaderboard?scope=station&period=month
```

---

## 7. Improvements & Additional Features to Build In

These are not optional extras — build them all.

### 7.1 Quick Incident Report
A bottom sheet accessible from the Home screen `[⊕ Report Incident]` button. Fields:
- Incident type (dropdown: Accident | Theft | Disturbance | Medical | Other)
- Location (auto-filled from GPS, tap to edit)
- Description (multi-line text)
- Severity estimate (Low / Medium / High chips)
- `[ SUBMIT REPORT ]`

### 7.2 Panic / Officer-in-Distress Button
In the Profile screen header, a discreet long-press gesture (3 seconds) on the badge hexagon triggers an SOS to the station. On trigger: vibrate 3 times, play distinct sound, send `POST /api/v1/officers/{id}/sos`. Show a red banner at the top of the screen until acknowledged. This must be hard to trigger accidentally (3-second hold with countdown circle feedback).

### 7.3 Offline Mode
If the officer has no internet connection:
- Show a persistent amber banner: `[⚠ Offline — data may be stale]`
- Home screen displays last cached shift stats from Hive
- History screen loads cached entries (last 50)
- Polling pauses, shows "Reconnecting..." badge state
- Auto-resumes polling when connectivity returns (use `connectivity_plus`)

### 7.4 End-of-Shift Summary
When an officer taps "End Shift" in the Go Offline confirmation sheet, before going offline, show a full-screen summary modal:
```
// SHIFT SUMMARY — 06:00 to 18:00 ─────────────────

  Duration .................. 12h 00m
  Dispatches handled ........ 4
  Avg response time ......... 5m 42s
  Distance covered .......... 23.4 km
  Rating this shift ......... 4.9 ★
  
  ┌─ Notable ──────────────────────────────────────┐
  │  🏆 Best response time today: 3m 12s (Alert #88)│
  └────────────────────────────────────────────────┘
  
  [ ✓ END SHIFT & LOG OUT ]    [ ↩ STAY ONLINE ]
```

### 7.5 Alert Notes During Navigation
On the Navigation screen, a small `[📝 Note]` FAB allows the officer to add a voice or text note attached to the current dispatch (stored locally, submitted with resolution).

### 7.6 Map Route Refresh
On the Navigation screen, a `[↻ Refresh Route]` button re-fetches the OSRM route in case traffic conditions have changed.

### 7.7 ETA Live Countdown
On the Navigation screen, the ETA shown in the bottom sheet must be a live countdown (`Duration` ticker using `Stream.periodic`), not a static number.

### 7.8 Dark/Light Theme Persistence
Theme preference saved to Hive on every change. Read on app startup. The `ThemeProvider` (Riverpod) initializes from Hive before the first frame.

### 7.9 Biometric Lock
Optional: after 5 minutes in background, require fingerprint/face ID to re-enter the app (use `local_auth` package). Toggled in Settings → Security.

### 7.10 Network Status Indicator
A 4dp wide vertical strip on the very left edge of the shell (visible on all tabs): green when connected + online, amber when connected + offline, red when no network. Subtle, not intrusive.

---

## 8. pubspec.yaml Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  go_router: ^13.0.0
  dio: ^5.4.3
  hive_flutter: ^1.1.0
  google_fonts: ^6.2.1
  flutter_map: ^6.1.0
  flutter_map_tile_caching: ^9.1.0
  latlong2: ^0.9.0
  geolocator: ^11.0.0
  audioplayers: ^6.0.0
  lottie: ^3.1.0
  fl_chart: ^0.67.0
  connectivity_plus: ^6.0.3
  local_auth: ^2.1.8
  permission_handler: ^11.3.0
  intl: ^0.19.0
  shared_preferences: ^2.2.3
```

---

## 9. Error Handling Standards

Every API call must handle these cases. Never show raw exception messages to the user.

| Scenario | Behavior |
|---|---|
| 401 Unauthorized | Clear session, push `/login` |
| 404 Not Found | Show `AlertCard` with "Resource not found" |
| 500 Server Error | Show snackbar "Server error — try again" |
| Network timeout | Show snackbar "Request timed out" + retry button |
| GPS unavailable | Show amber banner "Location unavailable" |
| No dispatch after accept | Pop route, show snackbar "Dispatch already taken" |

---

## 10. Animations & Micro-Interactions

| Element | Animation |
|---|---|
| Tab switch | `AnimatedSwitcher` with fade + slight slide |
| Home stats cards | Staggered fade-in on first load (50ms delay between each) |
| Online/Offline badge | Color transition `AnimatedContainer` (300ms) |
| Activity feed items | Slide in from bottom on insert |
| Incoming dispatch arrival | Scale in from 0.9 → 1.0 with fade (200ms) |
| Dispatch countdown bar | `LinearProgressIndicator` with `LinearProgressIndicatorTheme` |
| Slide-to-confirm | Spring physics on release: `SpringSimulation` |
| Map marker | Pulsing `AnimationController` (scale 1.0 → 1.4, repeat, 1s) |
| Resolution success | Lottie checkmark, auto-dismiss 1.5s |

---

## 11. Accessibility

- All tappable areas: minimum 48dp × 48dp.
- All icons have `Semantics(label: '...')` wrappers.
- Sufficient color contrast on all text (WCAG AA minimum).
- Screen reader support: `MergeSemantics` on stat cards.
- No color-only information (always pair color with icon or text).

---

## 12. Build Instructions

After generating all code:

1. Run `flutter pub get`.
2. Generate Hive adapters: `flutter packages pub run build_runner build`.
3. Ensure `google_fonts` caches are set for offline use in release mode.
4. Create `assets/sounds/alert.mp3` placeholder (any short tone file).
5. Create `assets/lottie/success.json` placeholder (a simple checkmark animation JSON).
6. Confirm `AndroidManifest.xml` has: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `USE_BIOMETRIC`, `VIBRATE`.
7. Confirm `Info.plist` has: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysUsageDescription`, `NSFaceIDUsageDescription`.

---

*End of prompt. Build all of it.*
