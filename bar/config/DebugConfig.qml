// GENERATED from shared/DebugConfig.qml by tools/sync-shared — do not edit
// =============================================================================
// shared/DebugConfig.qml — Debug Logging Configuration (canonical, synced copy)
// =============================================================================
//
// CANONICAL SOURCE: this file is the source of truth; bar/config/ and
// settings/config/ hold byte-identical copies (tools/sync-shared). The two
// shells are separate `-c` roots and Quickshell's VFS blocks imports that
// escape the root, so the file is SYNCED, not imported across — editing a
// root copy directly will fail tools/check-shared.
//
// Central debug flag for gating console.log statements across whichever
// shell this copy is synced into. Set debugEnabled to true for development,
// false for production.
//
// Usage:
//   if (Config.DebugConfig.debugEnabled) {
//       console.log("[Component] Debug message")
//   }
//
// =============================================================================

pragma Singleton

import QtQuick

QtObject {
    // =========================================================================
    // DEBUG FLAGS
    // =========================================================================

    // Master debug flag — gates all debug logging
    property bool debugEnabled: false

    // Specific debug categories (for granular control)
    property bool debugTheme: debugEnabled    // Theme-related logs
    property bool debugIPC: debugEnabled      // IPC-related logs
    property bool debugUI: debugEnabled        // UI state changes
    property bool debugFile: debugEnabled     // File operations
    property bool debugService: debugEnabled  // Service operations

    // =========================================================================
    // LOGGING HELPERS
    // =========================================================================

    // Conditional logging for theme operations
    function logTheme(message) {
        if (debugTheme) console.log("[Theme] " + message)
    }

    // Conditional logging for IPC operations
    function logIPC(message) {
        if (debugIPC) console.log("[IPC] " + message)
    }

    // Conditional logging for UI state
    function logUI(message) {
        if (debugUI) console.log("[UI] " + message)
    }

    // Conditional logging for file operations
    function logFile(message) {
        if (debugFile) console.log("[File] " + message)
    }

    // Conditional logging for service operations
    function logService(message) {
        if (debugService) console.log("[Service] " + message)
    }
}
