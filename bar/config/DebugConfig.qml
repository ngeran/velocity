// =============================================================================
// bar/config/DebugConfig.qml — Debug Logging Configuration
// =============================================================================
//
// Central debug flag for gating console.log statements across the bar shell.
// Set debugEnabled to true for development, false for production.
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
    property bool debugEnabled: true

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
