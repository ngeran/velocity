'use strict'
// shared-targets.js — the ONE registration table for shared/ sync files.
// Consumed by tools/sync-shared (distributor) and tools/check-shared (gate) so
// the two can never disagree about what is registered. Registering a new
// canonical file: add a row here (canonical relative path → per-root relative
// paths), run tools/sync-shared once. See shared/README.md for the model
// (VFS blocks cross-root imports; roots hold byte-identical synced copies).

module.exports = {
  'shared/MotionConfig.qml': ['bar/config/MotionConfig.qml', 'settings/config/MotionConfig.qml'],
  // P6.1: identity tokens (font families, spacing, radii) — the lock root is
  // a separate -c root too, so it gets its own synced copy.
  'shared/Tokens.qml': ['bar/config/Tokens.qml', 'settings/config/Tokens.qml', 'lock/Tokens.qml'],
  'shared/DebugConfig.qml': ['bar/config/DebugConfig.qml', 'settings/config/DebugConfig.qml'],
  'shared/BoundedProcess.qml': ['bar/services/BoundedProcess.qml', 'settings/services/BoundedProcess.qml'],
  'shared/LogService.qml': ['bar/services/LogService.qml'],   // P2.4: settings tab reads HostBridge.log
  'shared/LogModel.js': ['bar/services/LogModel.js'],         // P2.4: settings copy deleted with its service
  'shared/components/Sparkline.qml': ['settings/components/Sparkline.qml', 'bar/components/Sparkline.qml'],   // P4.1: card traffic sparkline
  // P4.10: the quick-access card set (frame/row/slider/toggle) — every bar
  // card body embeds these; settings pages that host card bodies reuse them.
  'shared/components/CardFrame.qml': ['bar/components/CardFrame.qml', 'settings/components/CardFrame.qml'],
  'shared/components/ListRow.qml': ['bar/components/ListRow.qml', 'settings/components/ListRow.qml'],
  'shared/components/CardRow.qml': ['bar/components/CardRow.qml', 'settings/components/CardRow.qml'],
  'shared/components/CardSlider.qml': ['bar/components/CardSlider.qml', 'settings/components/CardSlider.qml'],
  'shared/components/CardToggle.qml': ['bar/components/CardToggle.qml', 'settings/components/CardToggle.qml'],
  // P6.2: the dot-matrix divider — replaces 1 px hairlines in overlays/cards.
  // The lock root renders dot rules too (lock is a separate -c root).
  'shared/components/DotRule.qml': ['bar/components/DotRule.qml', 'settings/components/DotRule.qml',
                                    'lock/DotRule.qml'],
  'shared/theme-mix.mjs': ['bar/lib/theme-mix.mjs', 'settings/lib/theme-mix.mjs'],
  // P4.9: the keybinds table fallback — KeybindsOverlay (bar) and the
  // settings KEYBINDS page both render it when ~/.config/velocity/keybinds.json
  // is missing. tools/keybinds-default.json stays the semantic SSOT; check-ipc
  // keeps this file in lockstep with it.
  'shared/keybinds-default.mjs': ['bar/lib/keybinds-default.mjs', 'settings/lib/keybinds-default.mjs'],
  'shared/b64.mjs': ['bar/lib/b64.mjs'],
  'shared/theme-core.mjs': ['bar/lib/theme-core.mjs', 'settings/lib/theme-core.mjs'],
  'shared/theme-port.mjs': ['bar/lib/theme-port.mjs', 'settings/lib/theme-port.mjs'],   // P5.5: import/export (JSON + base16 YAML)
  'shared/theme-ingest.mjs': ['bar/lib/theme-ingest.mjs', 'settings/lib/theme-ingest.mjs'],   // P2.7: both ThemeConfig.qml's pure core
  'shared/orbit.mjs': ['bar/lib/orbit.mjs'],
  'shared/tz.mjs': ['settings/lib/tz.mjs', 'plugins/nikos.timezones/lib/tz.mjs', 'plugins/nikos.clock/lib/tz.mjs'],
  'shared/weather.mjs': ['plugins/nikos.clock/lib/weather.mjs', 'settings/lib/weather.mjs'],
  'shared/units.mjs': ['bar/lib/units.mjs', 'settings/lib/units.mjs'],
  'shared/calendar.mjs': ['plugins/nikos.clock/lib/calendar.mjs'],
  'shared/storage.mjs': ['plugins/nikos.storage/lib/storage.mjs', 'settings/lib/storage.mjs', 'bar/lib/storage.mjs'],
}
