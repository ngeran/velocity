# Wallpaper Picker & Shuffler Integration Plan

**Project:** Integrate wallpaper picker/shuffler functionality into QuickShell Settings
**Source:** `/home/nikos/.config/quickshell-pill/`
**Target:** `/home/nikos/.config/quickshell/`
**Aesthetic:** OLED-minimal style (from `ModernDashboard.qml`)

**Current Status:** Phases 1-5 Complete ✅ | Phase 6: Testing Pending | Additional Features: Compact Widgets + Info Cards + Shared State ✅

## Status Legend
- [ ] Todo
- [~] In Progress
- [x] Complete
- [!] Blocked

---

## Phase 1: Analysis & Planning ✅

### Tasks
- [x] 1.1 Analyze existing wallpaper-shuffler.qml from quickshell-pill
- [x] 1.2 Analyze WallpaperSettings.qml from quickshell-pill
- [x] 1.3 Analyze theme-control.sh script
- [x] 1.4 Understand OLED-minimal design language from ModernDashboard.qml
- [x] 1.5 Create integration plan

**Phase 1 Complete** ✅

---

## Phase 2: Core Wallpaper Shuffler Service ✅

### Tasks
- [x] 2.1 Create `/home/nikos/.config/quickshell/settings/services/WallpaperService.qml`
  - Clean IPC interface for wallpaper control
  - Directory scanning with `find` (no shell escaping issues)
  - Auto-cycle timer with configurable interval
  - Support for jpg, jpeg, png, webp formats
  - Transition effect settings (outer, fade, wipe, etc.)
  - State management for current wallpaper, cycling state

- [x] 2.2 Create `/home/nikos/.config/quickshell/settings/config/WallpaperConfig.qml`
  - Configuration constants
  - Default values matching modern aesthetic
  - Color scheme integration

---

## Phase 3: Wallpaper Settings UI Module ✅

### Tasks
- [x] 3.1 Create `/home/nikos/.config/quickshell/settings/components/WallpaperModule.qml`
  - **Section Header:** "WALLPAPERS" with minimal styling
  - **Controls Row:** 
    - Auto-cycle toggle (ON/OFF) with OLED pill styling
    - Manual cycle button
    - Interval control (+/- buttons with minute display)
  - **Transition Settings:** Radio-style buttons for transition types
  - **Directory Input:** Path input field with Reload button
  - **Status:** Wallpaper count + cycling status indicator
  - **Preview Grid:** 4-column thumbnail grid with:
    - Image previews
    - Active indicator (accent border)
    - Hover effects
    - Click to apply
  - **Theme Generation:** (Optional) Matugen integration button

---

## Phase 4: Integration into ModernDashboard ✅

### Tasks
- [x] 4.1 Update `/home/nikos/.config/quickshell/settings/components/ModernDashboard.qml`
  - Replace WALLPAPERS placeholder tab (TAB 2) with WallpaperModule
  - Ensure proper tab switching behavior
  - Maintain spacing and 1px divider rules

- [x] 4.2 Test tab navigation between OVERVIEW, THEMES, WALLPAPERS, SETTINGS

---

## Phase 5: Shell Integration

### Tasks
- [ ] 5.1 Update `/home/nikos/.config/quickshell/settings/shell.qml`
  - Add IPC handler for wallpaper controls if needed
  - Ensure proper window visibility toggle

- [ ] 5.2 Create `/home/nikos/.config/quickshell/settings/bin/wallpaper-control.sh` (optional)
  - Simplified version of theme-control.sh for wallpaper-specific operations
  - CLI interface for quickshell commands

---

## Phase 6: Testing & Validation

### Tasks
- [ ] 6.1 Verify wallpaper directory scanning works
- [ ] 6.2 Test auto-cycle toggle functionality
- [ ] 6.3 Test interval adjustment (+/- buttons)
- [ ] 6.4 Test manual wallpaper selection from grid
- [ ] 6.5 Test transition effects (outer, fade, wipe, etc.)
- [ ] 6.6 Test Matugen theme generation (if available)
- [ ] 6.7 Verify visual consistency with OLED-minimal aesthetic

---

## Design Specifications

### OLED-Minimal Aesthetic Rules
1. **Background:** Pure black `#000000`
2. **Dividers:** 1px `#1a1a1a` horizontal rules between sections
3. **Text Colors:**
   - Primary: `#cccccc`
   - Secondary: `#2e2e2e`
   - Accent: `#00dfe5` (teal/cyan)
   - Dim: `#2a2a2a`
4. **Borders:** 1px, no radius
5. **Active States:** Teal underline (2px height) for tabs
6. **Spacing:** 0 between sections (using divider rules instead)
7. **Font:** Small, tracked-out (letterSpacing: 1.8-2.5)

### Component Structure
```
WallpaperModule.qml
├── Section Header ("WALLPAPERS")
├── Controls Row
│   ├── Toggle (Auto On/Off)
│   ├── Manual Cycle Button
│   └── Interval Control ([-] value [+])
├── Transition Options (Outer | Fade | Wipe | Simple)
├── Directory Input (path + Load button)
├── Status Row (count + cycling indicator)
└── Preview Grid (4-column thumbnails)
```

---

## Dependencies
- `awww` or `swww` for wallpaper rendering
- `find` for directory scanning
- `matugen` (optional) for theme generation

---

## Files to Create
1. `/home/nikos/.config/quickshell/settings/services/WallpaperService.qml`
2. `/home/nikos/.config/quickshell/settings/config/WallpaperConfig.qml`
3. `/home/nikos/.config/quickshell/settings/components/WallpaperModule.qml`

## Files to Modify
1. `/home/nikos/.config/quickshell/settings/components/ModernDashboard.qml` (TAB 2)

---

## Notes from Source Code Analysis
- wallpaper-shuffler.qml uses `awww` (swww-compatible) for transitions
- IPC interface allows external control without state duplication
- Scan-in-progress guard prevents concurrent find processes
- Image thumbnails use asynchronous loading with fallback
- Interval steps: 1, 2, 5, 10, 15, 30, 60 minutes

---

## Additional Features Implemented ✅

### Compact Overview Widgets
Created compact versions of the overview widgets to save space:
- **ClockWidgetCompact.qml** — Smaller clock display (24px time vs 36px)
- **CalendarWidgetCompact.qml** — Reduced margins and font sizes
- **ResourcesWidgetCompact.qml** — Compact CPU/MEM/GPU bars

### Info Cards
Two new cards to display active theme and wallpaper information:
- **ThemeInfoCard.qml** — Shows active theme name, author, color swatches, OLED badge
- **WallpaperInfoCard.qml** — Shows current wallpaper thumbnail, filename, auto-cycle status, countdown to next

### New Dashboard Layout
Updated ModernDashboard.qml to use:
- Top row: Compact Clock | Compact Calendar | Compact Resources
- Bottom row: Theme Info Card | Wallpaper Info Card
- All separated by 1px #1a1a1a dividers

### Settings Persistence
Added ConfigPersistence.qml utility and integrated into WallpaperModule:
- Saves cycleInterval, cyclingEnabled, transitionType, wallpaperDir
- Loads settings on startup
- Auto-saves on any setting change (with 500ms debounce)

### Shared State Management
Created SharedState.qml singleton for cross-component communication:
- **WallpaperState**: wallpaperPath, wallpaperName, cyclingEnabled, cycleInterval, countdown, transitionType, count
- **ThemeState**: themeName, themeAuthor, isOLED, primaryColor, secondaryColor, textColor
- **SystemState**: cpuUsage, memUsage, gpuUsage, diskUsage
- WallpaperModule writes to SharedState on any change
- ThemeModule writes to SharedState on any change
- WallpaperInfoCard and ThemeInfoCard read from SharedState
- Built-in countdown timer for wallpaper cycling

---

*Last Updated: 2026-06-14*
