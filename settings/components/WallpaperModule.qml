import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../config" as Config
import "../services" as Services

Item {
    id: root
    
    // =========================================================================
    // STATE (binds to WallpaperService singleton)
    // =========================================================================
    // Use direct service bindings in UI elements instead of property copies
    // This ensures reactive updates when service properties change

    readonly property var wallpaperList: Services.WallpaperService.wallpaperList
    readonly property string currentWallpaper: Services.WallpaperService.currentWallpaper
    readonly property int cycleInterval: Services.WallpaperService.cycleInterval > 0 ? Services.WallpaperService.cycleInterval / 1000 : 300
    readonly property bool cyclingEnabled: Services.WallpaperService.cyclingEnabled
    readonly property string transitionType: Services.WallpaperService.transitionType || "outer"
    readonly property string wallpaperDir: Services.WallpaperService.wallpaperDir || "/home/nikos/Pictures/Wallpapers/"

    implicitWidth: 600
    implicitHeight: 800
    anchors.fill: parent

    // Debug logging to verify button clicks
    function debugLog(action, detail) {
        console.log("[WallpaperModule]", action, ":", detail)
    }

    // =========================================================================
    // WALLPAPER SERVICE FUNCTIONS (direct calls, no IPC)
    // =========================================================================
    function applyWallpaper(path) {
        debugLog("applyWallpaper", path)
        Services.WallpaperService.setWallpaperByPath(path)
    }

    function toggleCycling() {
        debugLog("toggleCycling", "current state:", cyclingEnabled)
        Services.WallpaperService.toggleCycling()
    }

    function setTransition(type) {
        debugLog("setTransition", type)
        Services.WallpaperService.setTransition(type)
    }

    function setInterval(seconds) {
        debugLog("setInterval", seconds, "seconds")
        Services.WallpaperService.setInterval(seconds)
    }

    function refreshWallpapers() {
        debugLog("refreshWallpapers", "triggering service refresh")
        Services.WallpaperService.refreshList()
    }

    function handleLoadDirectory(path) {
        debugLog("handleLoadDirectory", path)
        if (path.length === 0) return;
        Services.WallpaperService.setWallpaperDir(path);
        refreshDelay.start();
    }

    Timer { id: refreshDelay; interval: 400; onTriggered: refreshWallpapers() }

    // =========================================================================
    // UI LAYOUT
    // =========================================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 20

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "WALLPAPER MANAGEMENT"
                font.pixelSize: 11; font.bold: true; color: "#666"
                Layout.fillWidth: true
            }

            Rectangle {
                width: 120; height: 32; radius: 4
                color: root.cyclingEnabled ? "#34d399" : "#1f2937"

                Text {
                    anchors.centerIn: parent
                    text: root.cyclingEnabled ? "CYCLING: ON" : "CYCLING: OFF"
                    color: root.cyclingEnabled ? "#000" : "#fff"; font.pixelSize: 10; font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: {
                        console.log("[WallpaperModule] CYCLING BUTTON PRESSED!")
                        root.debugLog("Cycling toggle", "current state:", root.cyclingEnabled)
                        toggleCycling()
                    }
                }
            }
        }

        // Folder Input
        RowLayout {
            Layout.fillWidth: true
            height: 40; spacing: 10

            Rectangle {
                Layout.fillWidth: true; height: 40; color: "#111"; border.color: "#333"
                TextInput {
                    id: dirInput
                    anchors.fill: parent; anchors.leftMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#fff"
                    text: root.wallpaperDir
                    clip: true
                }
            }

            Rectangle {
                width: 80; height: 40; color: "#3b82f6"
                Text { anchors.centerIn: parent; text: "LOAD"; font.bold: true; color: "#fff" }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.debugLog("LOAD button", dirInput.text)
                        handleLoadDirectory(dirInput.text)
                    }
                }
            }
        }

        // Interval and Transition
        RowLayout {
            spacing: 30
            
            // Interval
            Row {
                spacing: 10
                Text { text: "INTERVAL"; color: "#666"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }

                // Decrease button
                Rectangle {
                    width: 24; height: 24; color: "#222"; radius: 4
                    Text { anchors.centerIn: parent; text: "[-]"; color: "#fff"; font.bold: true; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: { root.debugLog("Interval [-]", root.cycleInterval - 60); setInterval(root.cycleInterval - 60); } cursorShape: Qt.PointingHandCursor }
                }

                Text { text: (root.cycleInterval / 60).toFixed(0) + "m"; color: "#3b82f6"; font.bold: true; anchors.verticalCenter: parent.verticalCenter }

                // Increase button
                Rectangle {
                    width: 24; height: 24; color: "#222"; radius: 4
                    Text { anchors.centerIn: parent; text: "[+]"; color: "#fff"; font.bold: true; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: { root.debugLog("Interval [+]", root.cycleInterval + 60); setInterval(root.cycleInterval + 60); } cursorShape: Qt.PointingHandCursor }
                }
            }

            // Transitions
            Row {
                spacing: 5
                Repeater {
                    model: ["fade", "wipe", "outer"]
                    Rectangle {
                        width: 50; height: 24; color: root.transitionType === modelData ? "#3b82f6" : "#111"
                        border.color: "#333"
                        Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 9; color: "#fff" }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.debugLog("Transition", modelData)
                                setTransition(modelData)
                            }
                        }
                    }
                }
            }
        }

        // Preview Grid
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            GridView {
                id: grid
                anchors.fill: parent
                cellWidth: 160; cellHeight: 120
                model: root.wallpaperList
                clip: true
                delegate: Rectangle {
                    width: 150; height: 110; color: "#000"
                    border.color: root.currentWallpaper === modelData ? "#3b82f6" : "#333"
                    border.width: root.currentWallpaper === modelData ? 2 : 1

                    Image {
                        anchors.fill: parent; anchors.margins: 4
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.debugLog("Wallpaper click", modelData)
                            applyWallpaper(modelData)
                        }
                    }
                }
            }
        }
    }
}
