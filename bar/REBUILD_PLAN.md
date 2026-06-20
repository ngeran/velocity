# Rebuild Plan - quickshell-bar

Starting from scratch to debug QML import issues. Adding components incrementally.

## Tasks

- [x] **Task 1**: Create minimal working bar (empty) ✅
- [x] **Task 2**: Add design token config (BarConfig) - Skipped (using hardcoded values for now)
- [x] **Task 3**: Add ClockWidget component ✅
- [x] **Task 4**: Add WorkspaceWidget + HyprlandService ✅
- [x] **Task 5**: Add SystemTray components ✅
- [x] **Task 6**: Add NetworkService and NetworkIcon ✅
- [x] **Task 7**: Add BluetoothService and BluetoothIcon ✅
- [x] **Task 8**: Add AudioService and VolumeIcon ✅
- [x] **Task 9**: Add BatteryIcon ✅
- [x] **Task 10**: Update icon click handlers for TUI apps ✅

## Current Bar Layout

**Left**: Workspace dots (1-5, teal when active)
**Center**: Clock (HH:MM)
**Right**: W (Network) | B (Bluetooth) | V (Volume) | Battery

## Interactions

- **Workspaces**: Click dot to switch workspace
- **Network (W)**: Click to launch impala TUI
- **Bluetooth (B)**: Click to launch bluetui TUI
- **Volume (V)**: Scroll to adjust volume, click to launch wiremix TUI
- **Battery**: Click to show popup with battery percentage and status

## Notes

- Using Nerd Font icons (JetBrainsMono Nerd Font)
- All TUI apps launch in kitty with floating window class
- All services use polling (no socket events for simplicity)
