# RoadSOS HQ — Admin Dashboard
## Principal UX/UI Architecture Blueprint v1.0
### For: Junior AI Coding Agent — Full Implementation Reference

---

> **AGENT PRIME DIRECTIVE**
> Read this entire document before writing a single line of code.
> The hook `useDashboardData.js` is **immutable**. Its exported API
> (`activeSos`, `pastSos`, `activeReports`, `pastReports`, `isLoading`,
> `error`, `refreshData`) is the single source of truth. Never refactor,
> wrap, or alter it. Every component in this blueprint consumes these
> variables exactly as they are exported today.

---

## SECTION 1 — AESTHETIC VISION & DESIGN LANGUAGE

### 1.1 Conceptual Direction

**Theme: "Dark Ops Command Center"**

The dashboard is used by police headquarters operators in high-stress,
time-critical situations. The design must communicate authority,
precision, and urgency. The visual language is: deep space-black
backgrounds, structured glassmorphic panels that feel like hardened
tactical glass, and a strict traffic-light accent system (red = critical,
amber = caution, green = resolved). No decoration for decoration's sake.
Every pixel earns its place.

The single unforgettable element: active SOS alerts **pulse with a
living red glow** — as if the card itself has a heartbeat. An operator
glancing at a second monitor across the room must be able to instantly
identify that an emergency is live.

**Forbidden aesthetics for this project:**
- Purple gradients
- Rounded "friendly" UI (pill buttons everywhere)
- White or light backgrounds
- Pastel anything
- Generic loading spinners (use a precise line animation instead)

---

## SECTION 2 — DESIGN TOKENS

The agent must create one file: `src/styles/tokens.css`
This file must be imported FIRST in `index.css` (or the root CSS entry point).
Every component references these variables. No hardcoded hex values anywhere else.

```
FILE PATH: admin_dashboard/src/styles/tokens.css
```

### 2.1 Color Palette

```css
:root {

  /* ── BASE SURFACES ──────────────────────────────────── */
  --bg-void:          #070A10;   /* Absolute darkest base. Body background. */
  --bg-base:          #0B0F1A;   /* Primary app background. Main canvas. */
  --bg-surface-1:     #101622;   /* Cards, panels sitting on bg-base. */
  --bg-surface-2:     #161D2E;   /* Elevated hover state, nested cards. */
  --bg-glass:         rgba(16, 22, 34, 0.60); /* Glassmorphic fill. */
  --bg-glass-hover:   rgba(22, 29, 46, 0.75); /* Glass on hover. */

  /* ── BORDERS ────────────────────────────────────────── */
  --border-subtle:    rgba(255, 255, 255, 0.05);  /* Lowest division lines. */
  --border-default:   rgba(255, 255, 255, 0.09);  /* Card borders, dividers. */
  --border-strong:    rgba(255, 255, 255, 0.16);  /* Focused/hovered borders. */

  /* ── CRITICAL (ACTIVE SOS) ──────────────────────────── */
  --red-vivid:        #FF2D55;   /* Primary SOS accent. Text, icons. */
  --red-dim:          #C41F3E;   /* Darker red for gradients. */
  --red-glow-near:    rgba(255, 45, 85, 0.35);   /* Inner glow on SOS card. */
  --red-glow-far:     rgba(255, 45, 85, 0.10);   /* Outer spread glow. */
  --red-fill:         rgba(255, 45, 85, 0.08);   /* Subtle card tint. */
  --red-fill-hover:   rgba(255, 45, 85, 0.15);   /* Card hover tint. */
  --red-border:       rgba(255, 45, 85, 0.30);   /* Card border. */

  /* ── CAUTION (ACTIVE REPORTS) ───────────────────────── */
  --amber-vivid:      #FF9F0A;   /* Primary Accident Report accent. */
  --amber-dim:        #CC7A00;   /* Darker amber for depth. */
  --amber-glow-near:  rgba(255, 159, 10, 0.30);
  --amber-fill:       rgba(255, 159, 10, 0.07);
  --amber-fill-hover: rgba(255, 159, 10, 0.13);
  --amber-border:     rgba(255, 159, 10, 0.28);

  /* ── RESOLVED (PAST/ARCHIVE) ────────────────────────── */
  --green-vivid:      #30D158;   /* Resolved state. Badges. */
  --green-fill:       rgba(48, 209, 88, 0.08);
  --green-border:     rgba(48, 209, 88, 0.25);

  /* ── INFORMATION (DISPATCHED / OFFICER ASSIGNED) ────── */
  --blue-vivid:       #0A84FF;
  --blue-fill:        rgba(10, 132, 255, 0.08);
  --blue-border:      rgba(10, 132, 255, 0.25);

  /* ── TYPOGRAPHY ─────────────────────────────────────── */
  --text-primary:     #F0F2F5;   /* Headlines, important values. */
  --text-secondary:   #8A90A0;   /* Labels, metadata, secondary info. */
  --text-tertiary:    #4A5060;   /* Disabled states, divider labels. */
  --text-on-red:      #FF2D55;
  --text-on-amber:    #FF9F0A;
  --text-on-green:    #30D158;
  --text-on-blue:     #0A84FF;

  /* ── SHADOWS ────────────────────────────────────────── */
  --shadow-sm:        0 1px 4px rgba(0, 0, 0, 0.50);
  --shadow-md:        0 4px 16px rgba(0, 0, 0, 0.55),
                      0 1px 4px  rgba(0, 0, 0, 0.40);
  --shadow-lg:        0 8px 32px rgba(0, 0, 0, 0.65),
                      0 2px 8px  rgba(0, 0, 0, 0.45);
  --shadow-red-card:  0 0 24px var(--red-glow-near),
                      0 0 60px var(--red-glow-far),
                      0 4px 16px rgba(0, 0, 0, 0.55);
  --shadow-amber-card:0 0 20px var(--amber-glow-near),
                      0 4px 16px rgba(0, 0, 0, 0.55);

  /* ── GLASSMORPHISM ──────────────────────────────────── */
  --glass-blur:       blur(24px) saturate(160%);
  --glass-border:     1px solid var(--border-default);

  /* ── BORDER RADIUS ──────────────────────────────────── */
  --radius-xs:        6px;
  --radius-sm:        10px;
  --radius-md:        14px;
  --radius-lg:        20px;
  --radius-pill:      999px;

  /* ── SPACING SCALE ──────────────────────────────────── */
  --space-1:  4px;
  --space-2:  8px;
  --space-3:  12px;
  --space-4:  16px;
  --space-5:  20px;
  --space-6:  24px;
  --space-8:  32px;
  --space-10: 40px;
  --space-12: 48px;

  /* ── TRANSITIONS ────────────────────────────────────── */
  --ease-out-cubic: cubic-bezier(0.33, 1, 0.68, 1);
  --transition-fast:   120ms var(--ease-out-cubic);
  --transition-normal: 220ms var(--ease-out-cubic);

  /* ── SIDEBAR / LAYOUT DIMENSIONS ───────────────────── */
  --topbar-height:    60px;
  --left-panel-width: 220px;
  --right-feed-width: 300px;
}
```

### 2.2 Typography

```
Font stack:
  Display/Headings : 'Syne', sans-serif  (import from Google Fonts)
  Body/UI          : 'DM Sans', sans-serif (import from Google Fonts)
  Monospace (IDs, coordinates, timestamps) : 'JetBrains Mono', monospace (import from Google Fonts)

Google Fonts import URL (add to index.html <head>):
  https://fonts.googleapis.com/css2?family=Syne:wght@600;700;800&family=DM+Sans:wght@300;400;500;600&family=JetBrains+Mono:wght@400;500&display=swap
```

| Role | Font | Size | Weight | Color |
|---|---|---|---|---|
| App name / Display | Syne | 18px | 700 | `--text-primary` |
| Section headers | Syne | 13px | 700 | `--text-secondary` (uppercased, letter-spacing: 0.08em) |
| Card headline (location/ID) | DM Sans | 15px | 600 | `--text-primary` |
| Card body (name, type) | DM Sans | 13px | 400 | `--text-secondary` |
| Stat number (count) | Syne | 28px | 800 | `--text-primary` |
| Stat label | DM Sans | 11px | 500 | `--text-secondary` |
| Badge text | DM Sans | 10px | 600 | varies |
| Timestamp | JetBrains Mono | 11px | 400 | `--text-tertiary` |
| IDs, coordinates | JetBrains Mono | 11px | 500 | `--text-secondary` |

---

## SECTION 3 — LAYOUT ARCHITECTURE

### 3.1 Structural Overview (the "shell")

```
┌─────────────────────────────────────────────────────────────────────┐
│  TopCommandBar  (height: 60px, full width, position: sticky, top:0) │
│  [Logo] [Live Clock] [Sync Pulse] [3 Stat Chips] [Refresh Button]  │
├────────────────┬────────────────────────────────────┬───────────────┤
│                │                                    │               │
│  LeftPanel     │       MainCanvas                   │  AlertFeed    │
│  (220px fixed) │       (flex: 1)                    │  (300px fixed)│
│                │                                    │               │
│  • System      │  ┌─ SOS Section ────────────────┐  │  • Past SOS   │
│    Status      │  │  SectionHeader + Card grid   │  │    list items │
│    Indicator   │  │  (LiveIncidentCard × n)       │  │               │
│                │  └──────────────────────────────┘  │  ─ divider ─  │
│  • Officer     │                                    │               │
│    Count       │  ┌─ Reports Section ────────────┐  │  • Past       │
│    (static     │  │  SectionHeader + Card grid   │  │    Reports    │
│    placeholder)│  │  (LiveIncidentCard × n)       │  │    list items │
│                │  └──────────────────────────────┘  │               │
│  • Connection  │                                    │               │
│    status      │                                    │               │
│                │                                    │               │
└────────────────┴────────────────────────────────────┴───────────────┘
```

### 3.2 App-Level Layout CSS Class

In `index.css` (global styles), define the following layout structure.
Do not put this inside a component — it belongs at the global level.

```
Body:
  background: var(--bg-void);
  font-family: 'DM Sans', sans-serif;
  color: var(--text-primary);
  height: 100vh;
  overflow: hidden;  ← The app does NOT scroll at the body level.
                       Each panel scrolls independently.

.app-shell:
  display: flex;
  flex-direction: column;
  height: 100vh;

.app-body:
  display: flex;
  flex: 1;
  overflow: hidden;

.main-canvas:
  flex: 1;
  overflow-y: auto;
  padding: var(--space-6);
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
  scrollbar-width: thin;
  scrollbar-color: var(--border-default) transparent;
```

### 3.3 Responsive Breakpoints

```
≥ 1280px : Full 3-panel layout (left + main + right).
 960–1279px: LeftPanel collapses to icon-only strip (40px wide).
             Right AlertFeed stays.
< 960px  : LeftPanel hidden entirely (hamburger menu icon in TopCommandBar).
             AlertFeed moves below MainCanvas in a stacked layout.
             This is a LOWER PRIORITY. The agent should build the full
             desktop layout first, then add these breakpoints last.
```

---

## SECTION 4 — COMPONENT TREE (Complete File Map)

The agent must create EVERY file listed here. File paths are relative to
`admin_dashboard/src/`.

```
src/
│
├── styles/
│   └── tokens.css                    ← STEP 1: Create first. All design tokens.
│
├── components/
│   │
│   ├── layout/
│   │   ├── TopCommandBar.jsx         ← STEP 3
│   │   ├── LeftPanel.jsx             ← STEP 4
│   │   ├── MainCanvas.jsx            ← STEP 5
│   │   └── AlertFeed.jsx             ← STEP 6
│   │
│   ├── widgets/
│   │   ├── StatChip.jsx              ← STEP 7
│   │   ├── PulsingDot.jsx            ← STEP 8
│   │   ├── StatusBadge.jsx           ← STEP 9
│   │   ├── SectionHeader.jsx         ← STEP 10
│   │   ├── LiveIncidentCard.jsx      ← STEP 11  ← Most critical component.
│   │   ├── ArchiveListItem.jsx       ← STEP 12
│   │   └── EmptyState.jsx            ← STEP 13
│   │
│   └── overlays/
│       └── IncidentModal.jsx         ← STEP 14  ← Restyle only. Keep logic.
│
├── presentation/
│   └── state/
│       └── useDashboardData.js       ← DO NOT TOUCH. NEVER MODIFY.
│
├── data/                             ← DO NOT TOUCH.
└── domain/                           ← DO NOT TOUCH.
```

---

## SECTION 5 — DATA MAPPING (Hook → Component)

This section is the contract between data and UI. Every component's
props interface is defined here. The agent must follow this exactly.

### 5.1 Hook Export Reference

```javascript
// From useDashboardData.js — the immutable API surface:
const {
  activeSos,      // Array<{ id: any, data: object }> — live SOS incidents
  pastSos,        // Array<{ id: any, data: object }> — resolved SOS
  activeReports,  // Array<{ id: any, data: object }> — open accident reports
  pastReports,    // Array<{ id: any, data: object }> — resolved reports
  isLoading,      // boolean — true on first load
  error,          // string | null
  refreshData     // () => void — manual refresh trigger
} = useDashboardData(10000);
```

### 5.2 Component-Level Data Contracts

**`App.jsx` (the shell — only file)**
- Calls `useDashboardData(10000)`.
- Holds `selectedIncident` in local useState.
- Passes all hook results as props to layout children.
- Handles `onCardClick` callback → sets `selectedIncident`.
- Passes `onClose` / `onStatusChange` to `IncidentModal`.

**`TopCommandBar` props:**
```
isLoading    : boolean
error        : string | null
refreshData  : () => void
totalActive  : number  ← computed in App.jsx as activeSos.length + activeReports.length
totalSos     : number  ← activeSos.length
totalReports : number  ← activeReports.length
```

**`LeftPanel` props:**
```
No hook data. Renders static system-status UI only.
A future integration point — agent should render placeholder values.
```

**`MainCanvas` props:**
```
activeSos      : Array
activeReports  : Array
onCardClick    : (item: object, type: 'sos' | 'report') => void
```

**`AlertFeed` props:**
```
pastSos     : Array
pastReports : Array
onItemClick : (item: object, type: 'sos' | 'report') => void
```

**`LiveIncidentCard` props:**
```
item      : object  ← the `.data` field from the hook array item (e.g., a.data)
type      : 'sos' | 'report'
onClick   : (item: object, type: string) => void
```

**`ArchiveListItem` props:**
```
item   : object  ← the `.data` field
type   : 'sos' | 'report'
onClick: (item: object, type: string) => void
```

**`StatChip` props:**
```
value : number | string
label : string
accent: 'red' | 'amber' | 'green' | 'default'
```

**`StatusBadge` props:**
```
status : string  ← raw status string from backend (e.g., "ACTIVE", "DISPATCHED")
```

**`SectionHeader` props:**
```
icon  : React.ReactNode  ← a Lucide icon component
label : string
count : number
accent: 'red' | 'amber'
```

**`PulsingDot` props:**
```
color : 'red' | 'green' | 'amber'
size  : 'sm' | 'md'  ← default 'sm'
```

**`EmptyState` props:**
```
icon    : React.ReactNode
message : string
```

---

## SECTION 6 — DETAILED COMPONENT SPECIFICATIONS

### 6.1 `TopCommandBar.jsx`

**Visual Description:**
A 60px-tall horizontal bar, pinned to the top. It uses the glass
treatment: `backdrop-filter: var(--glass-blur)`, `background: var(--bg-glass)`,
`border-bottom: 1px solid var(--border-default)`. `position: sticky; top: 0; z-index: 100`.

**Left region — Brand:**
- `ShieldAlert` Lucide icon, color `var(--red-vivid)`, size 20.
- Text "ROADSOS HQ" using Syne font, 15px, weight 700, letter-spacing 0.12em,
  color `var(--text-primary)`.
- A 1px vertical divider `var(--border-default)` after the brand.

**Center region — Live Clock:**
- Displays current time formatted as `HH:MM:SS`. Uses a `useEffect` with
  `setInterval(fn, 1000)` inside `TopCommandBar` itself (this is local clock
  UI state, not backend data — it belongs here, not in the hook).
- Font: JetBrains Mono, 20px, weight 500, color `var(--text-primary)`.
- Below the time: date formatted as `"TUE, 02 JUN 2026"`, DM Sans 11px,
  `var(--text-tertiary)`.

**Right region — Status and Controls:**
- `<StatChip>` for total active incidents (accent: 'red'), SOS count, Report count.
- A sync pulse indicator: a small `<PulsingDot color="green" size="sm" />` next to
  the text "LIVE" in DM Sans 11px weight 600 color `var(--green-vivid)`. When
  `isLoading` is true, replace the dot with a tiny CSS line-spin animation
  (a 16px circle outline rotating) and change text to "SYNCING".
- If `error` is not null: render a red alert banner BELOW the bar (not inside),
  positioned as a thin 32px strip just below the navbar with text:
  `"⚠ Connection error: {error}"` in DM Sans 12px, background
  `rgba(255,45,85,0.12)`, border-bottom `1px solid var(--red-border)`.
- Manual Refresh button: icon `RotateCw` from Lucide, 16px, no label. Ghost style:
  no fill, border `1px solid var(--border-default)`, border-radius `var(--radius-sm)`,
  padding `6px 10px`. On hover: border becomes `var(--border-strong)`, background
  `var(--bg-surface-1)`. On click: calls `refreshData()`.

---

### 6.2 `LeftPanel.jsx`

**Visual Description:**
A 220px fixed-width vertical column. Background: `var(--bg-surface-1)`.
Right border: `1px solid var(--border-subtle)`. Padding: `var(--space-6) var(--space-4)`.
`overflow-y: auto`.

**Content (top to bottom):**

1. **Section label:** "SYSTEM STATUS" — Syne 10px, weight 700, letter-spacing
   0.1em, color `var(--text-tertiary)`. Uppercase. Padding-bottom 12px.

2. **Connection Block:**
   - A glass card (`var(--bg-glass)`, border `var(--glass-border)`,
     border-radius `var(--radius-md)`, padding `var(--space-4)`).
   - Row: `<PulsingDot color="green" size="sm" />` + "Backend Connected"
     DM Sans 13px `var(--text-secondary)`.
   - Sub-row: "Polling every 10s" — JetBrains Mono 11px `var(--text-tertiary)`.

3. **Divider** (1px `var(--border-subtle)`, margin: 20px 0).

4. **Section label:** "UNITS ON DUTY"

5. **Officer Count Block** (glass card):
   - A large Syne number "—" (em-dash, 32px weight 800) centered, representing
     the officer count (static placeholder for now — future API integration).
   - Below it: "Officers Active" DM Sans 11px `var(--text-secondary)`.
   - Note in code comment: `// TODO: Connect to /officers/active endpoint`

6. **Divider**

7. **Section label:** "RESPONSE ZONES"

8. **Zone Placeholder Block** (glass card):
   - Three rows, each with a colored dot and a label:
     - 🟢 "Zone Alpha — Clear"
     - 🟡 "Zone Bravo — Moderate"
     - 🔴 "Zone Charlie — High"
   - Static placeholder. Note in comment: `// TODO: Connect to zone API`

---

### 6.3 `MainCanvas.jsx`

**Visual Description:**
The main scrollable center. `flex: 1`, `overflow-y: auto`, `padding: var(--space-6)`,
`display: flex; flex-direction: column; gap: var(--space-8)`.

**Contains two stacked sections:**

**Section A — Active SOS Alerts:**
- `<SectionHeader icon={<Activity />} label="ACTIVE SOS ALERTS" count={activeSos.length} accent="red" />`
- If `activeSos.length === 0`: render `<EmptyState icon={<ShieldCheck />} message="All clear — no active SOS alerts." />`
- If not empty: render a CSS grid of `<LiveIncidentCard>` components.
  - Grid: `display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: var(--space-4);`
  - Map: `activeSos.map(a => <LiveIncidentCard key={a.id} item={a.data} type="sos" onClick={onCardClick} />)`

**Section B — Open Accident Reports:**
- `<SectionHeader icon={<Car />} label="OPEN ACCIDENT REPORTS" count={activeReports.length} accent="amber" />`
- Same pattern: EmptyState or grid of `<LiveIncidentCard type="report">`.
  - Map: `activeReports.map(r => <LiveIncidentCard key={r.id} item={r.data} type="report" onClick={onCardClick} />)`

---

### 6.4 `AlertFeed.jsx`

**Visual Description:**
A 300px fixed-width right panel. Background: `var(--bg-surface-1)`.
Left border: `1px solid var(--border-subtle)`. `overflow-y: auto`.
Padding: `var(--space-4)`.

**Header (sticky within the panel):**
- "INCIDENT ARCHIVE" label — Syne 10px uppercase letter-spacing 0.1em
  `var(--text-tertiary)`.
- `Clock` Lucide icon, 14px, `var(--text-tertiary)`.

**Content:**
- Sub-header: "SOS History" — DM Sans 11px 600 `var(--text-secondary)`.
- `pastSos.slice(0, 10).map(a => <ArchiveListItem key={a.id} item={a.data} type="sos" onClick={onItemClick} />)`
- If `pastSos.length === 0`: small italic text "No past SOS alerts."

- 1px `var(--border-default)` divider with centered label "REPORTS" styled
  as `<div class="feed-divider">`. Use `position: relative` with a pseudo-element
  ::before and ::after to create the ruled-line-with-text look. The lines are
  `var(--border-default)` color, the text is DM Sans 10px `var(--text-tertiary)`.

- Sub-header: "Report History"
- `pastReports.slice(0, 10).map(r => <ArchiveListItem key={r.id} item={r.data} type="report" onClick={onItemClick} />)`

---

### 6.5 `LiveIncidentCard.jsx` ← **MOST CRITICAL COMPONENT**

This is the centrepiece of the entire UI. The agent must implement it with
maximum care and precision.

**Visual Description (SOS variant — `type === 'sos'`):**
```
┌──────────────────────────────────────────┐  ← border: 1px solid var(--red-border)
│  ● ACTIVE  [SOS]    [Officer: Dispatched]│  ← status row
│                                          │
│  John Doe                                │  ← citizen name, 15px 600
│  Lat 12.97, Lng 80.21                    │  ← coords, mono font
│                                          │
│  🕐 2 mins ago      ID: #00421           │  ← footer row
└──────────────────────────────────────────┘
     ^
     Subtle left border accent (4px solid var(--red-vivid))
```

**Card Anatomy & CSS:**
```
.incident-card (base):
  background   : var(--bg-surface-1)
  border       : 1px solid var(--border-default)
  border-radius: var(--radius-md)
  padding      : var(--space-4) var(--space-5)
  cursor       : pointer
  transition   : all var(--transition-normal)
  position     : relative
  overflow     : hidden
  border-left  : 4px solid transparent  ← overridden per type

.incident-card::before (ambient glow layer):
  content    : ''
  position   : absolute
  inset      : 0
  opacity    : 0
  transition : opacity var(--transition-normal)
  pointer-events: none

.incident-card:hover::before:
  opacity: 1

.incident-card--sos:
  border-left-color : var(--red-vivid)
  background        : var(--red-fill)
  border-color      : var(--red-border)
  box-shadow        : var(--shadow-red-card)

.incident-card--sos::before:
  background: radial-gradient(ellipse at top left,
                var(--red-glow-near) 0%,
                transparent 65%)

.incident-card--sos:hover:
  background        : var(--red-fill-hover)
  transform         : translateY(-2px)
  box-shadow        : var(--shadow-red-card),
                      0 8px 32px var(--red-glow-near)

.incident-card--report:
  border-left-color : var(--amber-vivid)
  background        : var(--amber-fill)
  border-color      : var(--amber-border)
  box-shadow        : var(--shadow-amber-card)

.incident-card--report:hover:
  background        : var(--amber-fill-hover)
  transform         : translateY(-2px)
```

**SOS Card Pulse Animation:**
ONLY for `type === 'sos'` cards. The card's box-shadow (the glow) must
pulse. Define this keyframe in global CSS:

```css
@keyframes sos-pulse {
  0%, 100% {
    box-shadow: 0 0 18px var(--red-glow-near),
                0 0 40px var(--red-glow-far),
                0 4px 16px rgba(0,0,0,0.55);
  }
  50% {
    box-shadow: 0 0 32px rgba(255, 45, 85, 0.55),
                0 0 80px rgba(255, 45, 85, 0.20),
                0 4px 20px rgba(0,0,0,0.65);
  }
}

.incident-card--sos {
  animation: sos-pulse 2.5s ease-in-out infinite;
}

.incident-card--sos:hover {
  animation: none;  ← Stop pulse on hover to keep interaction clean.
}
```

**Card Content Layout:**

Row 1 (status row):
- `<PulsingDot color="red" size="sm" />` — only for SOS type.
  For report type: `<PulsingDot color="amber" size="sm" />`.
- Status text: Render `item.status` (if available) inside a `<StatusBadge>`.
- Push right: a secondary badge showing officer assignment if available.
  Check for `item.assigned_officer_name` or similar field. If present, show a
  `<StatusBadge>` with "DISPATCHED". If null, show "UNASSIGNED" in `--text-tertiary`.

Row 2 (identity):
- Render the most human-readable identifier. Priority order:
  1. `item.citizen_name` or `item.reporter_name`
  2. `item.phone_number`
  3. `"Unknown Reporter"`
- DM Sans 15px weight 600 `var(--text-primary)`.

Row 3 (location):
- If `item.latitude` and `item.longitude` exist:
  `Lat {item.latitude.toFixed(4)}, Lng {item.longitude.toFixed(4)}`
  Using JetBrains Mono 11px `var(--text-secondary)`.
- If not: `"Location unavailable"` in `var(--text-tertiary)`.

Row 4 (footer):
- Left: timestamp. If `item.created_at` or `item.timestamp` exists, format
  as relative time ("2 mins ago", "1 hr ago") using a simple helper function.
  JetBrains Mono 11px `var(--text-tertiary)`.
- Right: incident ID. `#${item.id}` — JetBrains Mono 11px `var(--text-tertiary)`.

**onClick:** When any area of the card is clicked, call
`onClick(item, type)`. This bubbles up to `App.jsx` which sets
`selectedIncident`.

**Agent note on field names:** The exact field names on `item.data` (the
backend payload) are unknown at blueprint time. The agent must implement
a **defensive data access pattern**:
```javascript
const name = item?.citizen_name
          ?? item?.reporter_name
          ?? item?.name
          ?? item?.user?.name
          ?? 'Unknown Reporter';
```
Do this for every field. Prefer optional chaining + nullish coalescing.
Never crash on a missing field.

---

### 6.6 `ArchiveListItem.jsx`

**Visual Description:**
A compact horizontal row. NOT a card — this is a list item style.
Height: approximately 52px. Full-width with 8px padding. On hover:
`background: var(--bg-surface-2)`. Border-radius `var(--radius-sm)`.
Border-bottom `1px solid var(--border-subtle)` (except last child).

**Layout:**
```
[Accent dot] [Name / ID]          [Time ago]
              [Status badge]
```

- Accent dot: a 6px circle, `var(--red-vivid)` for SOS, `var(--amber-vivid)` for report.
- Left block: Name (DM Sans 13px 500 `var(--text-primary)`) and `<StatusBadge>` below.
- Right block: relative time (JetBrains Mono 10px `var(--text-tertiary)`).
- `cursor: pointer`. On click: calls `onClick(item, type)`.

---

### 6.7 `StatChip.jsx`

A small pill component used in `TopCommandBar`.

**Structure:**
```
┌─────────────────────┐
│  28  Active Total   │
└─────────────────────┘
```

- Container: `background: var(--bg-surface-2)`, `border: 1px solid var(--border-default)`,
  `border-radius: var(--radius-pill)`, `padding: 4px 14px`, `display: inline-flex`,
  `align-items: center`, `gap: 8px`.
- Value: Syne 18px weight 700. Color from accent prop:
  - `'red'`    → `var(--red-vivid)`
  - `'amber'`  → `var(--amber-vivid)`
  - `'green'`  → `var(--green-vivid)`
  - `'default'`→ `var(--text-primary)`
- Label: DM Sans 11px weight 500 `var(--text-secondary)`.

---

### 6.8 `PulsingDot.jsx`

A reusable animated dot for "live" indicators.

**CSS (define in global CSS or a CSS module):**
```css
@keyframes dot-pulse {
  0%, 100% { transform: scale(1);   opacity: 1; }
  50%       { transform: scale(1.5); opacity: 0.6; }
}

.pulsing-dot {
  border-radius: 50%;
  animation: dot-pulse 1.8s ease-in-out infinite;
  flex-shrink: 0;
}

.pulsing-dot--sm { width: 7px;  height: 7px; }
.pulsing-dot--md { width: 10px; height: 10px; }

.pulsing-dot--red   { background: var(--red-vivid);
                       box-shadow: 0 0 6px var(--red-glow-near); }
.pulsing-dot--amber { background: var(--amber-vivid);
                       box-shadow: 0 0 6px var(--amber-glow-near); }
.pulsing-dot--green { background: var(--green-vivid);
                       box-shadow: 0 0 5px rgba(48, 209, 88, 0.5); }
```

**JSX:** A single `<span>` with the appropriate classes derived from props.

---

### 6.9 `StatusBadge.jsx`

Maps a raw backend status string to a styled pill badge.

**Status → Style mapping table:**

| Status value (case-insensitive) | Label text | Background | Text color |
|---|---|---|---|
| `ACTIVE`, `OPEN`, `PENDING` | ACTIVE | `var(--red-fill)` | `var(--red-vivid)` |
| `DISPATCHED`, `ASSIGNED` | DISPATCHED | `var(--blue-fill)` | `var(--blue-vivid)` |
| `RESOLVED`, `CLOSED`, `PAST` | RESOLVED | `var(--green-fill)` | `var(--green-vivid)` |
| `INVESTIGATING`, `IN_PROGRESS` | IN PROGRESS | `var(--amber-fill)` | `var(--amber-vivid)` |
| anything else | `status` (raw) | `var(--bg-surface-2)` | `var(--text-secondary)` |

**CSS base:**
```
display: inline-flex;
align-items: center;
padding: 2px 8px;
border-radius: var(--radius-pill);
font-family: 'DM Sans', sans-serif;
font-size: 10px;
font-weight: 600;
letter-spacing: 0.06em;
text-transform: uppercase;
border: 1px solid (a 40% opacity version of the text color);
```

---

### 6.10 `SectionHeader.jsx`

A standardized section heading row for `MainCanvas`.

**Structure:**
```
[Icon]  ACTIVE SOS ALERTS   [count badge: 3]
────────────────────────────────────────────  ← 1px border line below
```

- Row: `display: flex; align-items: center; gap: var(--space-2); margin-bottom: var(--space-4)`.
- Icon: cloned with `color: var(--red-vivid)` if `accent='red'`, `var(--amber-vivid)` if `accent='amber'`, size 16.
- Label: Syne 11px weight 700 letter-spacing 0.1em uppercase `var(--text-secondary)`.
- Count badge: small pill, `background: var(--red-fill)` for red accent,
  text color `var(--red-vivid)`. DM Sans 11px 600. If count is 0: use
  `var(--bg-surface-2)` background, `var(--text-tertiary)` text.
- Divider line: `border-bottom: 1px solid var(--border-subtle)`, `padding-bottom: var(--space-3)`.

---

### 6.11 `EmptyState.jsx`

Rendered when a list is empty.

**Visual:**
A centered column inside its container. `padding: var(--space-10) var(--space-6)`.
- Icon: 32px, color `var(--text-tertiary)`.
- Message text: DM Sans 13px `var(--text-tertiary)` centered.
- Optional soft glow: a 60px blurred radial element behind the icon
  using a `::before` pseudo, color `var(--border-default)`.

---

### 6.12 `IncidentModal.jsx` (Restyle Only)

The existing `IncidentModal` component's logic is presumed to work. The
agent must only restyle its visual presentation to match the new design system.

**Visual changes to apply:**
- Background overlay: `rgba(7, 10, 16, 0.85)`, `backdrop-filter: blur(8px)`.
- Modal box: `background: var(--bg-glass)`, `backdrop-filter: var(--glass-blur)`,
  `border: 1px solid var(--border-strong)`, `border-radius: var(--radius-lg)`,
  `box-shadow: var(--shadow-lg)`.
- Max width: 520px. Min width: 360px. Centered via `position: fixed; inset: 0;
  display: flex; align-items: center; justify-content: center;`.
- Header: type-specific colored banner: for SOS, `border-top: 3px solid var(--red-vivid)`.
  For report, `border-top: 3px solid var(--amber-vivid)`.
- Close button: `X` icon top-right, ghost style matching refresh button spec.
- All text inside: apply the new typography tokens.
- All badges inside: use the new `<StatusBadge>` component.
- Buttons (status change actions): solid background using accent color.
  Example: "Mark Resolved" button → `background: var(--green-vivid)`,
  `color: #000`, `border-radius: var(--radius-sm)`, `padding: 10px 20px`,
  DM Sans 14px weight 600.

---

## SECTION 7 — NEW `App.jsx` (Shell Architecture)

The agent must **completely replace** all existing JSX in `App.jsx`.
The file must look like this EXACT structure (this is an architectural
description, not literal code to copy — the agent writes real JSX):

```
App.jsx structure:

1. Imports:
   - React, { useState, useEffect } from 'react'
   - { useDashboardData } from './presentation/state/useDashboardData'
   - { TopCommandBar }   from './components/layout/TopCommandBar'
   - { LeftPanel }       from './components/layout/LeftPanel'
   - { MainCanvas }      from './components/layout/MainCanvas'
   - { AlertFeed }       from './components/layout/AlertFeed'
   - { IncidentModal }   from './components/overlays/IncidentModal'
   - './styles/tokens.css'

2. Hook call:
   const { activeSos, pastSos, activeReports, pastReports,
           isLoading, error, refreshData } = useDashboardData(10000);

3. Local state:
   const [selectedIncident, setSelectedIncident] = useState(null);

4. Sync effect (preserve existing logic from old App.jsx verbatim):
   useEffect(() => {
     if (selectedIncident) { ... sync selected incident with latest data ... }
   }, [activeSos, pastSos, activeReports, pastReports]);

5. Handler:
   const handleCardClick = (item, type) => setSelectedIncident({ item, type });
   const handleClose = () => setSelectedIncident(null);
   const handleStatusChange = () => { refreshData(); setSelectedIncident(null); };

6. JSX return:
   <div className="app-shell">
     <TopCommandBar
       isLoading={isLoading}
       error={error}
       refreshData={refreshData}
       totalActive={activeSos.length + activeReports.length}
       totalSos={activeSos.length}
       totalReports={activeReports.length}
     />
     <div className="app-body">
       <LeftPanel />
       <MainCanvas
         activeSos={activeSos}
         activeReports={activeReports}
         onCardClick={handleCardClick}
       />
       <AlertFeed
         pastSos={pastSos}
         pastReports={pastReports}
         onItemClick={handleCardClick}
       />
     </div>
     {selectedIncident && (
       <IncidentModal
         incident={selectedIncident.item}
         type={selectedIncident.type}
         onClose={handleClose}
         onStatusChange={handleStatusChange}
       />
     )}
   </div>

IMPORTANT: The useEffect sync logic from the original App.jsx
(lines 10-18 of the original) must be preserved exactly in the new
App.jsx. Do not simplify or remove it.
```

---

## SECTION 8 — GLOBAL CSS STRUCTURE (`index.css`)

The agent must add the following rules to the EXISTING `index.css`
(do not delete existing rules — APPEND or carefully merge):

```
Order of contents in index.css:
1. @import url(Google Fonts) — Syne, DM Sans, JetBrains Mono
2. @import './styles/tokens.css'
3. *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
4. html, body, #root { height: 100%; }
5. body { background: var(--bg-void); ... }
6. Scrollbar styles (custom thin scrollbar for all panels)
7. .app-shell layout class
8. .app-body layout class
9. @keyframes sos-pulse
10. @keyframes dot-pulse
11. .pulsing-dot and modifier classes
12. .feed-divider styles
13. Utility classes:
    .mono { font-family: 'JetBrains Mono', monospace; }
    .text-red    { color: var(--red-vivid); }
    .text-amber  { color: var(--amber-vivid); }
    .text-green  { color: var(--green-vivid); }
    .text-muted  { color: var(--text-tertiary); }
```

---

## SECTION 9 — EXECUTION STEPS (Numbered Agent Instructions)

The agent must execute these steps IN ORDER. Do not skip. Do not reorder.

**STEP 1 — Create Design Token File**
Create `admin_dashboard/src/styles/tokens.css`.
Copy the token definitions from Section 2.1 exactly.

**STEP 2 — Update Global CSS**
Modify `admin_dashboard/src/index.css` following the structure in Section 8.
Add Google Fonts import. Add keyframes. Add utility classes.
Do NOT delete any existing rules that may be referenced elsewhere until
all new components are created and old components are verified unused.

**STEP 3 — Create `TopCommandBar.jsx`**
Create `admin_dashboard/src/components/layout/TopCommandBar.jsx`.
Follow Section 6.1 specification exactly.
Use Lucide icons: `ShieldAlert`, `RotateCw`.
Implement the live clock with a local `useEffect` + `useState`.
Implement the `StatChip` and `PulsingDot` imports (even though those
files don't exist yet — the agent will stub them, then complete in
subsequent steps).

**STEP 4 — Create `LeftPanel.jsx`**
Create `admin_dashboard/src/components/layout/LeftPanel.jsx`.
Follow Section 6.2. All static placeholder content. No hook data.

**STEP 5 — Create Widget Components (in this order):**

  5a. Create `PulsingDot.jsx` (Section 6.8) — simplest, has no deps.
  5b. Create `StatusBadge.jsx` (Section 6.9) — only string logic.
  5c. Create `SectionHeader.jsx` (Section 6.10) — depends on nothing.
  5d. Create `StatChip.jsx` (Section 6.7) — depends on nothing.
  5e. Create `EmptyState.jsx` (Section 6.11) — depends on nothing.

**STEP 6 — Create `LiveIncidentCard.jsx`**
This is the most complex component. Follow Section 6.5 with full
precision. Implement the defensive data access pattern. Implement
the CSS class conditional logic (`incident-card--sos` vs
`incident-card--report`). The pulse animation class must be applied
ONLY for SOS type.

**STEP 7 — Create `ArchiveListItem.jsx`**
Follow Section 6.6. Much simpler than LiveIncidentCard.

**STEP 8 — Create `MainCanvas.jsx`**
Follow Section 6.3. Imports: `SectionHeader`, `LiveIncidentCard`,
`EmptyState`. Uses `Activity` and `Car` from Lucide.

**STEP 9 — Create `AlertFeed.jsx`**
Follow Section 6.4. Imports: `ArchiveListItem`, `Clock` from Lucide.
Implement the `.feed-divider` style locally or use global utility class.

**STEP 10 — Restyle `IncidentModal.jsx`**
Apply only visual/CSS changes per Section 6.12.
Do NOT change any prop interfaces, event handlers, or business logic.
Use `StatusBadge` for status display inside the modal.

**STEP 11 — Rewrite `App.jsx`**
Replace all JSX content following the exact shell architecture in Section 7.
Preserve the `useEffect` sync logic from the original App.jsx verbatim.
The file should be noticeably shorter than the original — it is a pure
composition shell with no inline styles.

**STEP 12 — Integration Verification Checklist**
After completing all files, verify:
- [ ] `useDashboardData.js` is completely unmodified (diff against original).
- [ ] `App.jsx` calls `useDashboardData(10000)` with the same interval.
- [ ] All hook variables are consumed: `activeSos`, `pastSos`,
      `activeReports`, `pastReports`, `isLoading`, `error`, `refreshData`.
- [ ] No component uses hardcoded hex color values — all use CSS variables.
- [ ] The SOS pulse animation runs on live SOS cards.
- [ ] The clock in TopCommandBar ticks in real time.
- [ ] Clicking any LiveIncidentCard or ArchiveListItem opens IncidentModal.
- [ ] The `refreshData()` function is wired to the manual refresh button.
- [ ] The error banner appears/disappears reactively based on `error` state.

**STEP 13 — Final Polish Pass**
- Add `title` attributes to icon-only buttons for accessibility.
- Ensure all `map()` calls have stable `key` props (use `a.id`, not index).
- Add `overflow: hidden` to `TopCommandBar` to prevent content overflow on
  small widths.
- Verify no console warnings about unknown DOM props or key duplicates.

---

## SECTION 10 — QUICK REFERENCE: ACCENT COLOR LOGIC

This table is the single decision point for which accent to use.
The agent must apply this consistently across ALL components.

| Data source | Accent color | CSS variable group |
|---|---|---|
| `activeSos` items | CRITICAL RED | `--red-*` |
| `activeReports` items | CAUTION AMBER | `--amber-*` |
| `pastSos` items | MUTED (resolved) | `--green-*` for badge, `--text-tertiary` for text |
| `pastReports` items | MUTED (resolved) | `--green-*` for badge, `--text-tertiary` for text |
| Sync/live status | LIVE GREEN | `--green-*` |
| Error / disconnect | CRITICAL RED | `--red-*` |
| Officer dispatched | INFO BLUE | `--blue-*` |

---

## SECTION 11 — LUCIDE ICON USAGE MAP

The agent uses ONLY the following Lucide icons. No other icon library.

| Component | Icon | Purpose |
|---|---|---|
| `TopCommandBar` | `ShieldAlert` | Brand logo |
| `TopCommandBar` | `RotateCw` | Manual refresh |
| `TopCommandBar` | `Clock` | Sync/live indicator (optional) |
| `MainCanvas` | `Activity` | SOS section header |
| `MainCanvas` | `Car` | Reports section header |
| `LeftPanel` | `Wifi` | Connection status |
| `LeftPanel` | `Users` | Officer count |
| `LeftPanel` | `MapPin` | Zone section |
| `AlertFeed` | `Clock` | Archive header |
| `EmptyState` | `ShieldCheck` | SOS empty state |
| `EmptyState` | `CheckCircle` | Reports empty state |
| `IncidentModal` | `X` | Close button |
| `IncidentModal` | `MapPin` | Location row |
| `IncidentModal` | `User` | Reporter row |
| `IncidentModal` | `Clock` | Timestamp row |

Import from: `import { ShieldAlert, RotateCw, ... } from 'lucide-react';`

---

*Blueprint authored by: Principal UX/UI Architecture Division*
*Target: RoadSOS Admin Dashboard — Web Application v2.0*
*Compatible with: React 18, useDashboardData.js (immutable), Lucide-react*
