// =============================================================================
// settings/components/ModernDashboard.qml
// Bento Grid Dashboard — Main Layout Orchestrator (Obsidian Vertical Edition)
// =============================================================================
//
// PURPOSE:
//   Reconstructs the dashboard architecture to match the strict pixel-perfect
//   layout, padding, text metrics, and alignment rules of the HTML blueprint.
//   Enforces exact 12×12 container distributions, resolving stretching gaps
//   in the calendar layout and centering anomalies in the sidebar panels.
//
// REAL DEVICE DATA:
//   - System time and date from device
//   - Network SSID from device Wi-Fi connection
//   - IP address from device network interface
//   - Signal strength from device Wi-Fi
//   - Weather data from system (if available)
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

import "." as Components
import "../config" as Config
import "../services" as Services

Item {
    id: root

    // =========================================================================
    // PUBLIC PROPERTIES
    // =========================================================================

    property int currentTab: 0

    // =========================================================================
    // PRIVATE PROPERTIES — bound to real device data via NetworkService
    // =========================================================================

    // Signal strength (0–100), driven by real WiFi signal (nmcli SIGNAL/100).
    // Ethernet reports 1.0 (full); disconnected reports 0.
    property real signalLevel: Math.round(Services.NetworkService.signalStrength * 100)

    // Real-time throughput (MB/s), computed from rxBytes/txBytes deltas.
    property real speedDown: 0
    property real speedUp: 0

    // Last-seen byte counters for delta-based speed calculation.
    property real _rxLast: 0
    property real _txLast: 0

    // =========================================================================
    // REAL DEVICE DATA HELPERS
    // =========================================================================

    // Format cumulative bytes (from /proc/net/dev) as KB/MB/GB.
    function formatBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB"
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB"
        return (b / 1024).toFixed(0) + " KB"
    }

    // =========================================================================
    // IDENTITY — real OS username (replaces hardcoded mockup name)
    // =========================================================================

    property string userName: "USER"

    Process {
        id: userProbe
        command: ["sh", "-c", "whoami"]
        running: true   // one-shot on load
        property string buffer: ""
        stdout: SplitParser { onRead: function(data) { userProbe.buffer += data } }
        onRunningChanged: {
            if (!running) {
                var u = userProbe.buffer.trim()
                if (u.length > 0)
                    root.userName = u.charAt(0).toUpperCase() + u.slice(1)
                userProbe.buffer = ""
            }
        }
    }

    // =========================================================================
    // CALENDAR — real current month grid (replaces hardcoded "OCTOBER GRID")
    // =========================================================================

    readonly property var _calToday: new Date()
    readonly property int _calYear: root._calToday.getFullYear()
    readonly property int _calMonth: root._calToday.getMonth()
    readonly property int _calTodayDate: root._calToday.getDate()
    readonly property var _calMonthNames: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]
    property string calMonthLabel: root._calMonthNames[root._calMonth] + " " + root._calYear
    property var calCells: root._buildCalendarCells()

    // Build the 35 date cells for the current month: leading prev-month days for
    // the weekday offset, this month's days (today flagged), trailing next-month.
    function _buildCalendarCells() {
        var year = root._calYear
        var month = root._calMonth
        var todayDate = root._calTodayDate
        var firstDay = new Date(year, month, 1).getDay()       // 0=Sun … 6=Sat
        var daysInMonth = new Date(year, month + 1, 0).getDate()
        var prevLast = new Date(year, month, 0).getDate()
        var cells = []

        var i
        for (i = firstDay - 1; i >= 0; i--)
            cells.push({ day: prevLast - i, isThisMonth: false, isToday: false })
        for (var d = 1; d <= daysInMonth; d++)
            cells.push({ day: d, isThisMonth: true, isToday: (d === todayDate) })
        var n = 1
        while (cells.length < 35)
            cells.push({ day: n++, isThisMonth: false, isToday: false })
        return cells
    }

    // =========================================================================
    // TIMERS FOR LIVE UPDATES
    // =========================================================================

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            var h = String(now.getHours()).padStart(2, '0')
            var m = String(now.getMinutes()).padStart(2, '0')
            clockHours.text = h
            clockMinutes.text = m
            
            // Format date: "MMM D YYYY" e.g., "Oct 31 2025"
            var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", 
                         "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
            var month = months[now.getMonth()]
            var day = now.getDate()
            var year = now.getFullYear()
            clockDateDisplay.text = month + " " + day + " " + year
        }
    }

    // -------------------------------------------------------------------------
    // Throughput timer — compute real MB/s from rxBytes/txBytes deltas.
    // Aligned to NetworkService's 1.5s /proc/net/dev poll so deltas are sane.
    // -------------------------------------------------------------------------
    Timer {
        id: speedTimer
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            var rxNow = Services.NetworkService.rxBytes
            var txNow = Services.NetworkService.txBytes

            // Δbytes ÷ interval(s) ÷ 1048576 = MB/s. Negative delta means the
            // interface changed or the counter rolled over — reset the baseline.
            if (rxNow < _rxLast || txNow < _txLast) {
                speedDown = 0
                speedUp = 0
            } else if (_rxLast > 0) {
                speedDown = ((rxNow - _rxLast) / 1.5) / 1048576
                speedUp = ((txNow - _txLast) / 1.5) / 1048576
            }

            _rxLast = rxNow
            _txLast = txNow

            speedDownText.text = speedDown.toFixed(1)
            speedUpText.text = speedUp.toFixed(1)

            // Traffic bars: download scaled to a 100 MB/s ceiling, upload to 20.
            var downW = Math.min(speedDown / 100, 1.0) * trafficDownContainer.width
            var upW = Math.min(speedUp / 20, 1.0) * trafficUpContainer.width
            trafficDownBar.width = downW
            trafficUpBar.width = upW
        }
    }

    // Redraw the signal ring only when the real device signal actually moves.
    // signalLevel is a binding on NetworkService.signalStrength, so this is
    // event-driven (no polling). Guarded for the pre-creation evaluation pass.
    onSignalLevelChanged: {
        if (signalRingCanvas) signalRingCanvas.requestPaint()
    }

    Component.onCompleted: {
        // Prime the live clock immediately (avoids a 1s blank state).
        var now = new Date()
        clockHours.text = String(now.getHours()).padStart(2, '0')
        clockMinutes.text = String(now.getMinutes()).padStart(2, '0')

        var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN",
                     "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        clockDateDisplay.text = months[now.getMonth()] + " " + now.getDate() + " " + now.getFullYear()

        // Network values (SSID / IP / signal / speed) bind to NetworkService
        // declaratively below — no imperative init needed. Paint the ring once
        // so it shows the current signal before the first signalLevelChanged.
        signalRingCanvas.requestPaint()

        // Build the calendar grid imperatively. A `var`-array property binding
        // can race the readonly date props at creation time, yielding an empty
        // grid — assigning here guarantees the cells populate and the Repeater
        // delegates re-evaluate against the populated array.
        root.calCells = root._buildCalendarCells()
    }

    // =========================================================================
    // CANVAS RECTANGLE (Pure Black Mirror Finish)
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: Config.ThemeConfig.colors.background
        radius: 0
    }

    // =========================================================================
    // TOP NAVIGATION HEADER (Row 1 Area)
    // =========================================================================

    Components.TopNavBar {
        id: navBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: parent.height * (1.0 / 12.0)
        currentIndex: root.currentTab
        onTabSelected: function(index) {
            root.currentTab = index
        }
    }

    // =========================================================================
    // MAIN CONTENT ORCHESTRATOR (Rows 2-12 Area)
    // =========================================================================

    Item {
        id: contentArea
        anchors {
            top: navBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        // =====================================================================
        // TAB 0: DASHBOARD OVERVIEW SYSTEM
        // =====================================================================

        Item {
            id: overviewTab
            visible: root.currentTab === 0
            anchors.fill: parent

            // -----------------------------------------------------------------
            // LEFT COLUMN PROFILE PANEL (Width: 4/12 Columns = 33.33%)
            // -----------------------------------------------------------------

            Item {
                id: leftColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    bottom: parent.bottom
                }
                width: parent.width * (4.0 / 12.0)

                // Identity Widget (Top Panel)
                Item {
                    id: identityCard
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: parent.height * 0.36

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        width: parent.width

                        // Avatar Container
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 80
                            height: 80
                            color: "transparent"
                            border.color: Config.ThemeConfig.colors.primary
                            border.width: 1
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                color: "#1a1a1a"
                                clip: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "B"
                                    font.pixelSize: 36
                                    font.family: "JetBrains Mono"
                                    font.weight: Font.Black
                                    color: Config.ThemeConfig.colors.primary
                                    opacity: 0.8
                                }
                            }
                        }

                        // Name - White color (real OS username)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.userName
                            font.pixelSize: 20
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            color: Config.ThemeConfig.colors.primary
                            font.letterSpacing: -0.5
                        }

                        // Status Indicator
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: "#00f5ff"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "ACTIVE"
                                font.pixelSize: 9
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                color: Config.ThemeConfig.colors.textDim
                                font.letterSpacing: 0.2
                                opacity: 0.6
                            }
                        }
                    }
                }

                // Separator Border
                Rectangle {
                    id: identityDivider
                    anchors {
                        top: identityCard.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Config.ThemeConfig.colors.border
                }

                // Clock Widget (Center Panel - Centered text alignment metrics)
                Item {
                    id: clockCard
                    anchors {
                        top: identityDivider.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: parent.height * 0.24

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        // Time Display: Hours + Minutes (no colon)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4

                            Text {
                                id: clockHours
                                text: "10"
                                font.pixelSize: 36
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                color: Config.ThemeConfig.colors.primary
                                font.letterSpacing: -1
                            }

                            Text {
                                id: clockMinutes
                                text: "57"
                                font.pixelSize: 36
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                color: "#00f5ff"
                                font.letterSpacing: -1
                            }
                        }

                        // Date Display (centered, below time)
                        Text {
                            id: clockDateDisplay
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "OCT 31 2025"
                            font.pixelSize: 9
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            color: Config.ThemeConfig.colors.textDim
                            font.letterSpacing: 0.2
                            opacity: 0.4
                        }
                    }
                }

                // Separator Border
                Rectangle {
                    id: clockDivider
                    anchors {
                        top: clockCard.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Config.ThemeConfig.colors.border
                }

                // Weather Widget (Lower Panel)
                Item {
                    id: weatherCard
                    anchors {
                        top: clockDivider.bottom
                        left: parent.left
                        right: parent.right
                        bottom: footerBar.top
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        width: parent.width * 0.7

                        // Weather Icon
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "⛅"
                            font.pixelSize: 28
                            color: Config.ThemeConfig.colors.primary
                            opacity: 0.8
                        }

                        // Temperature
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2

                            Text {
                                text: "14"
                                font.pixelSize: 28
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                color: Config.ThemeConfig.colors.primary
                                font.letterSpacing: -1
                            }

                            Text {
                                text: "°"
                                font.pixelSize: 11
                                font.family: "JetBrains Mono"
                                font.weight: Font.Bold
                                color: "#00f5ff"
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                            }
                        }

                        // Weather Description
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "BROKEN CLOUDS"
                            font.pixelSize: 8
                            font.family: "JetBrains Mono"
                            font.weight: Font.Black
                            color: Config.ThemeConfig.colors.textDim
                            font.letterSpacing: 0.2
                            opacity: 0.4
                        }

                        // Weather Details
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Config.ThemeConfig.colors.border
                                opacity: 0.5
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                spacing: 0

                                Column {
                                    width: parent.width / 2
                                    spacing: 2

                                    Text {
                                        text: "HUMIDITY"
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 7
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        color: Config.ThemeConfig.colors.textDim
                                        font.letterSpacing: 0.2
                                        opacity: 0.3
                                    }

                                    Text {
                                        text: "64%"
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 8
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        color: Config.ThemeConfig.colors.textDim
                                        opacity: 0.6
                                    }
                                }

                                Column {
                                    width: parent.width / 2
                                    spacing: 2

                                    Text {
                                        text: "WIND"
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 7
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        color: Config.ThemeConfig.colors.textDim
                                        font.letterSpacing: 0.2
                                        opacity: 0.3
                                    }

                                    Text {
                                        text: "12KM/H"
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: 8
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        color: Config.ThemeConfig.colors.textDim
                                        opacity: 0.6
                                    }
                                }
                            }
                        }
                    }
                }

                // Sidebar Footer
                Rectangle {
                    id: footerBar
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 44
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 16

                        Text {
                            text: "STABLE_V4"
                            font.pixelSize: 8
                            font.family: "JetBrains Mono"
                            color: "#00f5ff"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            height: 1
                            width: parent.width * 0.6
                            color: Config.ThemeConfig.colors.border
                            opacity: 0.3
                        }
                    }
                }
            }

            // PRIMARY SYSTEM AXIS SEPARATOR
            Rectangle {
                id: axisVerticalDivider
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: leftColumn.right
                }
                width: 1
                color: Config.ThemeConfig.colors.border
            }

            // -----------------------------------------------------------------
            // RIGHT COLUMN PANEL (Width: 8/12 Columns = 66.67%)
            // -----------------------------------------------------------------

            Item {
                id: rightColumn
                anchors {
                    top: parent.top
                    left: axisVerticalDivider.right
                    right: parent.right
                    bottom: parent.bottom
                }

                // Network Command Section (Top Panel)
                Item {
                    id: networkCard
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: parent.height * 0.46

                    // Padding container with proper margins to prevent cutoff
                    Item {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 16
                            topMargin: 12
                            bottomMargin: 12
                        }

                        // Header
                        Row {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }
                            height: 20

                            Text {
                                text: "NETWORK COMMAND"
                                font.pixelSize: 10
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                color: Config.ThemeConfig.colors.textDim
                                font.letterSpacing: 0.3
                                opacity: 0.4
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width * 0.5
                                height: parent.height
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                // Pulse indicator
                                Item {
                                    width: 12
                                    height: 12
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: "#00f5ff"
                                        z: 1
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: "transparent"
                                        border.color: "#00f5ff"
                                        border.width: 1
                                        opacity: 0.5
                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0; duration: 1500 }
                                            NumberAnimation { to: 0.5; duration: 500 }
                                        }
                                    }
                                }

                                Text {
                                    text: "ACTIVE TRAFFIC"
                                    font.pixelSize: 9
                                    font.family: "JetBrains Mono"
                                    color: "#00f5ff"
                                    font.letterSpacing: 0.2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Main Network Content Row - with proper sizing
                        Item {
                            anchors {
                                top: parent.top
                                topMargin: 28
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }

                            Row {
                                anchors.fill: parent
                                spacing: 16

                                // Signal Ring Gauge - fixed size
                                Item {
                                    width: 100
                                    height: 100
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Canvas for ring gauge
                                    Canvas {
                                        id: signalRingCanvas
                                        anchors.fill: parent
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)

                                            var centerX = width / 2
                                            var centerY = height / 2
                                            var radius = 46
                                            var lineWidth = 5

                                            // Track (background ring)
                                            ctx.beginPath()
                                            ctx.arc(centerX, centerY, radius, -Math.PI/2, Math.PI*1.5)
                                            ctx.strokeStyle = "#111111"
                                            ctx.lineWidth = lineWidth
                                            ctx.stroke()

                                            // Fill ring (signal level)
                                            ctx.beginPath()
                                            ctx.arc(centerX, centerY, radius, -Math.PI/2, -Math.PI/2 + (2 * Math.PI * signalLevel / 100))
                                            ctx.strokeStyle = "#00f5ff"
                                            ctx.lineWidth = lineWidth
                                            ctx.lineCap = "square"
                                            ctx.stroke()
                                        }
                                    }

                                    // Center text
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 0

                                        Text {
                                            id: signalPercentText
                                            text: Math.round(signalLevel) + "%"
                                            font.pixelSize: 22
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Black
                                            color: Config.ThemeConfig.colors.primary
                                            font.letterSpacing: -1
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }

                                        Text {
                                            text: "INTEGRITY"
                                            font.pixelSize: 6
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Black
                                            color: Config.ThemeConfig.colors.textDim
                                            font.letterSpacing: 0.2
                                            opacity: 0.4
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                    }
                                }

                                // Network Details Grid - with proper spacing
                                Column {
                                    width: parent.width - 116
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    // SSID
                                    Row {
                                        width: parent.width
                                        spacing: 8

                                        Column {
                                            width: parent.width / 2 - 4
                                            spacing: 1

                                            Text {
                                                text: "SSID"
                                                font.pixelSize: 7
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Black
                                                color: Config.ThemeConfig.colors.textDim
                                                font.letterSpacing: 0.2
                                                opacity: 0.4
                                            }

                                            Text {
                                                id: ssidText
                                                text: Services.NetworkService.ssid || "DISCONNECTED"
                                                font.pixelSize: 11
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Bold
                                                color: Config.ThemeConfig.colors.primary
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        Column {
                                            width: parent.width / 2 - 4
                                            spacing: 1

                                            Text {
                                                text: "IP ADDRESS"
                                                font.pixelSize: 7
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Black
                                                color: Config.ThemeConfig.colors.textDim
                                                font.letterSpacing: 0.2
                                                opacity: 0.4
                                            }

                                            Text {
                                                id: ipAddressText
                                                text: Services.NetworkService.ipAddress || "NO IP"
                                                font.pixelSize: 11
                                                font.family: "JetBrains Mono"
                                                font.weight: Font.Medium
                                                color: "#00f5ff"
                                            }
                                        }
                                    }

                                    // Traffic Analysis
                                    Column {
                                        width: parent.width
                                        spacing: 3

                                        Text {
                                            text: "TRAFFIC ANALYSIS"
                                            font.pixelSize: 7
                                            font.family: "JetBrains Mono"
                                            font.weight: Font.Black
                                            color: Config.ThemeConfig.colors.textDim
                                            font.letterSpacing: 0.2
                                            opacity: 0.4
                                        }

                                        // Traffic Bars Row
                                        Row {
                                            width: parent.width
                                            spacing: 12

                                            // Download
                                            Column {
                                                width: parent.width / 2 - 6
                                                spacing: 1

                                                Row {
                                                    spacing: 3

                                                    Text {
                                                        id: speedDownText
                                                        text: "0.0"
                                                        font.pixelSize: 16
                                                        font.family: "JetBrains Mono"
                                                        font.weight: Font.Black
                                                        color: Config.ThemeConfig.colors.primary
                                                        font.letterSpacing: -1
                                                    }

                                                    Text {
                                                        text: "MB/S"
                                                        font.pixelSize: 6
                                                        font.family: "JetBrains Mono"
                                                        font.weight: Font.Bold
                                                        color: Config.ThemeConfig.colors.textDim
                                                        opacity: 0.3
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: 2
                                                    }
                                                }

                                                // Progress bar
                                                Item {
                                                    id: trafficDownContainer
                                                    width: parent.width
                                                    height: 2
                                                    clip: true

                                                    Rectangle {
                                                        id: trafficDownBar
                                                        width: 0
                                                        height: parent.height
                                                        color: "#00f5ff"
                                                    }

                                                    Rectangle {
                                                        width: parent.width
                                                        height: parent.height
                                                        color: Config.ThemeConfig.colors.border
                                                        opacity: 0.3
                                                        z: -1
                                                    }
                                                }
                                            }

                                            // Upload
                                            Column {
                                                width: parent.width / 2 - 6
                                                spacing: 1

                                                Row {
                                                    spacing: 3

                                                    Text {
                                                        id: speedUpText
                                                        text: "0.0"
                                                        font.pixelSize: 16
                                                        font.family: "JetBrains Mono"
                                                        font.weight: Font.Black
                                                        color: Config.ThemeConfig.colors.primary
                                                        font.letterSpacing: -1
                                                    }

                                                    Text {
                                                        text: "MB/S"
                                                        font.pixelSize: 6
                                                        font.family: "JetBrains Mono"
                                                        font.weight: Font.Bold
                                                        color: Config.ThemeConfig.colors.textDim
                                                        opacity: 0.3
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: 2
                                                    }
                                                }

                                                // Progress bar
                                                Item {
                                                    id: trafficUpContainer
                                                    width: parent.width
                                                    height: 2
                                                    clip: true

                                                    Rectangle {
                                                        id: trafficUpBar
                                                        width: 0
                                                        height: parent.height
                                                        color: "#00f5ff"
                                                        opacity: 0.7
                                                    }

                                                    Rectangle {
                                                        width: parent.width
                                                        height: parent.height
                                                        color: Config.ThemeConfig.colors.border
                                                        opacity: 0.3
                                                        z: -1
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Workspace Horizontal Separator
                Rectangle {
                    id: networkCalendarDivider
                    anchors {
                        top: networkCard.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Config.ThemeConfig.colors.border
                }

                // Calendar Grid Section (Bottom Panel - Expanded Flex Filling)
                Item {
                    id: calendarCard
                    anchors {
                        top: networkCalendarDivider.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    // Calendar Header
                    Rectangle {
                        id: calendarHeader
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        height: 40
                        color: "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16

                            Text {
                                text: root.calMonthLabel
                                font.pixelSize: 10
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                color: Config.ThemeConfig.colors.primary
                                font.letterSpacing: 0.4
                                opacity: 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width * 0.7
                                height: parent.height
                            }

                            Text {
                                text: "▦"
                                font.pixelSize: 14
                                color: Config.ThemeConfig.colors.textDim
                                opacity: 0.4
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        anchors {
                            top: calendarHeader.bottom
                            left: parent.left
                            right: parent.right
                        }
                        height: 1
                        color: Config.ThemeConfig.colors.border
                    }

                    // Calendar Grid - Fills remaining space
                    Grid {
                        id: calendarGrid
                        anchors {
                            top: calendarHeader.bottom
                            left: parent.left
                            right: parent.right
                            bottom: calendarFooter.top
                            margins: 0
                        }
                        columns: 7
                        rows: 6
                        spacing: 1

                        property var dayLabels: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

                        Repeater {
                            model: 42

                            Rectangle {
                                width: (calendarGrid.width - 6) / 7
                                height: (calendarGrid.height - 5) / 6
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (index < 7) return calendarGrid.dayLabels[index]
                                        var cell = root.calCells[index - 7]
                                        return cell ? cell.day : ""
                                    }
                                    font.pixelSize: index < 7 ? 9 : 10
                                    font.family: "JetBrains Mono"
                                    font.weight: {
                                        if (index < 7) return Font.Black
                                        var cell = root.calCells[index - 7]
                                        return (cell && cell.isToday) ? Font.Black : Font.Medium
                                    }
                                    color: {
                                        if (index < 7) return Config.ThemeConfig.colors.primary
                                        var cell = root.calCells[index - 7]
                                        if (!cell) return Config.ThemeConfig.colors.textDim
                                        if (cell.isToday) return "#000000"
                                        if (cell.isThisMonth) return Config.ThemeConfig.colors.primary
                                        return Config.ThemeConfig.colors.textDim
                                    }
                                    opacity: {
                                        if (index < 7) return 1.0
                                        var cell = root.calCells[index - 7]
                                        if (!cell) return 0.3
                                        if (cell.isToday) return 1.0
                                        if (cell.isThisMonth) return 0.85
                                        return 0.3
                                    }
                                }

                                // Today highlight (real current day)
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.7
                                    height: parent.height * 0.7
                                    color: {
                                        var cell = root.calCells[index - 7]
                                        return (cell && cell.isToday) ? Config.ThemeConfig.colors.primary : "transparent"
                                    }
                                    z: -1
                                }

                                // Top border for day labels
                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                    }
                                    height: 1
                                    color: Config.ThemeConfig.colors.border
                                    visible: index < 7
                                    opacity: 0.3
                                }
                            }
                        }
                    }

                    // Calendar Footer
                    Rectangle {
                        id: calendarFooter
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        height: 32
                        color: Config.ThemeConfig.colors.border
                        opacity: 0.5

                        Row {
                            anchors.fill: parent
                            anchors.margins: 16

                            Text {
                                text: "SYSTEM SYNC ACTIVE"
                                font.pixelSize: 8
                                font.family: "JetBrains Mono"
                                font.weight: Font.Black
                                color: Config.ThemeConfig.colors.textDim
                                font.letterSpacing: 0.2
                                opacity: 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                width: parent.width * 0.7
                                height: parent.height
                            }

                            Text {
                                text: "0xFC12"
                                font.pixelSize: 8
                                font.family: "JetBrains Mono"
                                font.weight: Font.Medium
                                color: "#00f5ff"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // TAB 1: THEME SELECTION AREA
        // =====================================================================

        Components.ThemeModule {
            id: themeTab
            visible: root.currentTab === 1
            anchors.fill: parent
            anchors.margins: 24
        }

        // =====================================================================
        // TAB 2: WALLPAPER MANAGEMENT
        // =====================================================================

        Components.WallpaperModule {
            id: wallpaperTab
            visible: root.currentTab === 2
            anchors.fill: parent
        }

        // =====================================================================
        // TAB 3: SETTINGS PANEL WITH QUICK TOGGLES
        // =====================================================================

        Item {
            id: settingsTab
            visible: root.currentTab === 3
            anchors.fill: parent

            Column {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 24
                }
                spacing: 24

                // Header
                Text {
                    text: "QUICK SETTINGS"
                    font.pixelSize: 11
                    font.family: "JetBrains Mono"
                    font.letterSpacing: 2.5
                    font.weight: Font.Bold
                    color: Config.ThemeConfig.colors.textDim
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Config.ThemeConfig.colors.border
                }

                // Quick Toggles Grid
                Components.QuickTogglesGrid {
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // System Info Card
                Components.SysInfoCard {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
