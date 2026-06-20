---
name: nikos-qml
description: >
  Build Quickshell/QML desktop widgets and dashboard components for Nikos's
  Hyprland environment. Use whenever working on any QML file, Quickshell
  shell.qml entrypoint, component layout, ring gauges, hardware probes, or
  Aether/Matugen theme integration. Trigger on: QML, Quickshell, ShellRoot,
  PanelWindow, GridLayout, BentoCard, shell.qml, widget, ring gauge, OLED
  dashboard, Hyprland overlay, Process probe, pragma Singleton, Colors.qml,
  Aether theme, Matugen.
---

# Nikos QML / Quickshell Skill

## Design System

All Quickshell components follow the **Obsidian/OLED Bento** aesthetic.

| Token            | Value       | Usage                                      |
|------------------|-------------|--------------------------------------------|
| `background`     | `#000000`   | Window base, OLED true black               |
| `surface`        | `#0d0d0d`   | Card fill                                  |
| `surfaceContainer`| `#111111`  | Ring track, inset elements                 |
| `outline`        | `#2a2a2a`   | Primary card border                        |
| `outlineVariant` | `#1a1a1a`   | Dividers, separators                       |
| `primary`        | `#ffffff`   | Headings, key values                       |
| `textMuted`      | `#666666`   | Labels, captions, metadata                 |
| `textVariant`    | `#999999`   | Secondary body text                        |
| `accentCyan`     | `#00dce5`   | Primary accent (Aether/Matugen target)     |
| `accentBlue`     | `#00A2FD`   | Secondary accent                           |
| `accentWarn`     | `#FFB300`   | Threshold warnings                         |
| `accentErr`      | `#FF4C4C`   | Critical / down states                     |

Typography: `font.family: "monospace"` on all text. Never use system default sans-serif — breaks the terminal aesthetic.

---

## Project File Tree

```
~/.config/quickshell/
├── shell.qml                     # ShellRoot entrypoint — grid layout only
└── components/
    ├── Colors.qml                # pragma Singleton palette (Aether target)
    ├── BentoCard.qml             # Reusable card container (border + inset)
    ├── NetworkRing.qml           # Circular gauge (Shape + ShapePath)
    ├── IdentityWidget.qml        # Avatar + username + status dot
    ├── ClockWidget.qml           # Self-contained live HH:MM + date
    ├── NetworkWidget.qml         # Ring + SSID/IP probes (Process)
    └── CalendarWidget.qml        # Auto-generated monthly grid
```

---

## Import Pattern

```qml
// In shell.qml or any component that needs the full set:
import "components" as UI

// Usage:
UI.Colors.accentCyan       // singleton property
UI.BentoCard { ... }       // component instantiation
UI.NetworkRing { ... }
```

**Never** use relative `import "./components"` — use named namespace `as UI` only.

Colors.qml uses `pragma Singleton`. It is auto-registered as a singleton when the
`components/` directory is imported as a namespace — no `qmldir` file needed for
this pattern in Quickshell.

---

## Critical Layout Rules

### GridLayout — correct pattern

```qml
GridLayout {
    anchors.fill: parent
    rows: 12; columns: 12
    rowSpacing: 0; columnSpacing: 0

    UI.BentoCard {
        Layout.row: 0;    Layout.column: 0
        Layout.rowSpan: 1; Layout.columnSpan: 12
        Layout.fillWidth: true; Layout.fillHeight: true
    }
}
```

### Anchor conflicts — NEVER DO THIS

```qml
// ❌ WRONG — mixing anchors and Layout on same item
Item {
    anchors.centerIn: parent   // conflicts with GridLayout management
    Layout.fillWidth: true
}

// ✅ CORRECT — use Layout.alignment for centering inside GridLayout
Item {
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    Layout.fillWidth: true
}
```

### Children inside BentoCard

BentoCard uses `default property alias cardContent: container.data`.
Children placed inside BentoCard are automatically parented to its inner `container` Item.
Use `anchors.fill: parent` on the child widget to fill the card:

```qml
UI.BentoCard {
    Layout.row: 1; Layout.column: 0
    Layout.rowSpan: 3; Layout.columnSpan: 6
    Layout.fillWidth: true; Layout.fillHeight: true

    UI.ClockWidget {
        anchors.fill: parent
        anchors.margins: 32
    }
}
```

---

## Self-Contained Component Patterns

### Timer inside a component (preferred)

Each widget owns its own Timer. Do NOT define a global Timer in shell.qml and
pass values down — this creates tight coupling and breaks widget reuse.

```qml
// Inside ClockWidget.qml or any self-refreshing component
Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true   // Populate immediately — no 1s blank state on load
    onTriggered: { /* update internal property */ }
}
```

### Process probe (shell command output)

```qml
import Quickshell.Io

Process {
    id: myProbe
    command: ["ip", "-4", "route", "get", "1"]
    running: true

    stdout.onStreamedLine: (line) => {
        let match = line.match(/src\s+([\d.]+)/)
        if (match) myProperty = match[1]
    }

    onExited: (code) => {
        if (code !== 0) myProperty = "ERROR"
    }
}

// Re-poll timer
Timer {
    interval: 5000; running: true; repeat: true
    onTriggered: myProbe.running = true
}
```

---

## NetworkRing — Ring Gauge

```qml
UI.NetworkRing {
    width: 160; height: 160
    integrityValue: 0.85   // 0.0–1.0
    label: "SIGNAL"        // Optional center label
}
```

Key implementation notes:
- `startAngle: -90` = 12 o'clock start (CSS conic-gradient convention)
- `sweepAngle: integrityValue * 360`
- `layer.enabled: true` + `layer.samples: 4` = GPU-baked MSAA texture
- `Behavior on integrityValue` with `NumberAnimation` for smooth transitions
- Radius is `(width / 2) - strokeWidth` to keep arc inside bounds

---

## Aether / Matugen Integration

### Runtime color update flow

1. Aether rewrites `~/.config/quickshell/components/Colors.qml`
2. Sends IPC to Quickshell to hot-reload accent values
3. Only `property color` (not `readonly property color`) tokens are writable

**Colors.qml runtime-writable tokens** (no `readonly`):
- `accentCyan`, `accentBlue`, `accentWarn`, `accentErr`

**Colors.qml static tokens** (with `readonly`):
- `background`, `surface`, `surfaceContainer`, `outline`, `outlineVariant`
- `primary`, `textMuted`, `textVariant`

### Aether config mapping

```json
// ~/.config/aether/custom/dashboard/config.json
{
  "template": "Colors.qml",
  "destination": "~/.config/quickshell/components/Colors.qml",
  "post_apply": "quickshell ipc call 'UI.Colors.accentCyan = \"{color1}\"'"
}
```

---

## PanelWindow — Quickshell Window Layer

```qml
PanelWindow {
    width: 680; height: 680
    WlrLayerShell.layer:         WlrLayerShell.Layer.Top
    WlrLayerShell.exclusionMode: WlrLayerShell.ExclusionMode.None
    color: UI.Colors.background
}
```

- `Layer.Top`: above normal windows, below fullscreen. Use `Layer.Overlay` for above everything.
- `ExclusionMode.None`: does NOT reserve screen space (unlike a status bar).
- Do NOT use `anchors.centerIn: parent` on PanelWindow — position via WlrLayerShell anchors.

---

## Debugging

```bash
# Interactive mode — syntax errors and QML warnings print to stdout
quickshell --debug --inspect

# Watch for these common errors:
# "Cannot anchor to undefined" — missing anchors.fill: parent on inner widget
# "Binding loop detected" — circular property dependency
# "Type X is not a type" — component not found; check import path
# "Cannot assign to read-only property" — Colors.qml token marked readonly
```

### Common fixes

| Error | Cause | Fix |
|-------|-------|-----|
| Component not resolved | Wrong import path | Use `import "components" as UI` not `import "./components"` |
| High CPU from vectors | Shape redraws every frame | Set `layer.enabled: true` on Shape |
| IPC can't update color | Variable in local scope | Declare in Colors.qml singleton only |
| Blank 1-second delay | `triggeredOnStart` missing | Add `triggeredOnStart: true` to Timer |
| Anchor loop on GridLayout child | Mixed anchors + Layout | Remove anchors, use `Layout.alignment` |

---

## BentoCard — Correct vs Incorrect Usage

```qml
// ✅ CORRECT — child fills the card interior
UI.BentoCard {
    Layout.row: 4; Layout.column: 0
    Layout.rowSpan: 8; Layout.columnSpan: 7
    Layout.fillWidth: true; Layout.fillHeight: true

    UI.NetworkWidget {
        anchors.fill: parent
        anchors.margins: 40
    }
}

// ❌ WRONG — setting explicit width/height on a GridLayout child
UI.BentoCard {
    width: 340; height: 400    // overrides Layout management
    Layout.row: 4; Layout.column: 0
}
```

---

## Reference Files

- `components/Colors.qml` — singleton palette, Aether target
- `components/BentoCard.qml` — reusable card with `default property alias`
- `components/NetworkRing.qml` — Shape-based ring gauge
- `components/IdentityWidget.qml` — avatar + status row
- `components/ClockWidget.qml` — self-contained live clock
- `components/NetworkWidget.qml` — Process probes + ring + metadata
- `components/CalendarWidget.qml` — dynamic monthly grid
- `shell.qml` — ShellRoot + PanelWindow + 12×12 GridLayout entrypoint
