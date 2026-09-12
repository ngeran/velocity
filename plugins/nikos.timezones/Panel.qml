// =============================================================================
// nikos.timezones — worldtimebuddy working-hours grid (plugin panel body)
// =============================================================================
// This file's children are placed inside the host PluginPanel's body slot.
// One 24-cell strip per zone, columns aligned on the HOME day; each cell is
// that moment's hour IN THE ZONE; tints = zone work(8-18)/day(6-23)/night;
// accent line = now; hovering a column converts every header time.
// =============================================================================
import QtQuick
import "." as TZ

Item {
    id: gridRoot
    width: parent.width

    // Injected by BarWidget’s Loader — object refs to the shell singletons
    // (never imported: absolute-vs-relative import forks singleton instances).
    property var hostBar: null
    property var hostTheme: null

    // Geometry (fits PluginPanel contentWidth 800: 150 + 12 + 24*24+23)
    readonly property real cellW: 24
    readonly property real cellH: 34
    readonly property real headerW: 150
    readonly property real stripW: 24 * cellW + 23
    property int hoverCol: -1

    readonly property double dayStart: TZ.TimezoneService.dayStartUtc(TZ.TimezoneService.now)
    readonly property double nowCol: TZ.TimezoneService.nowColumn(TZ.TimezoneService.now)

    implicitWidth: headerW + 12 + stripW
    implicitHeight: TZ.TimezoneService.zones.length * (cellH + 4) - 4 + 18

    Column {
        id: rows
        spacing: 4
        Repeater {
            model: TZ.TimezoneService.zones

            Item {
                width: gridRoot.headerW + 12 + gridRoot.stripW
                height: gridRoot.cellH

                // Row header: place (abbr) · time · offset / date-roll
                Column {
                    width: gridRoot.headerW
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Row {
                        spacing: 5
                        Text {
                            text: modelData.home
                                  ? (TZ.TimezoneService.localZoneName || modelData.label)
                                  : modelData.label
                            font.family: hostBar.fontFamily; font.pixelSize: 11
                            font.bold: modelData.home === true
                            color: hostBar.colorText
                            elide: Text.ElideRight
                            width: gridRoot.headerW - 40
                        }
                        Text {
                            text: {
                                var a = TZ.TimezoneService.abbrFor(modelData.zone)
                                return a !== "" ? "(" + a + ")" : ""
                            }
                            font.family: hostBar.fontFamily; font.pixelSize: 8
                            color: hostBar.colorTextDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Row {
                        spacing: 5
                        Text {
                            text: {
                                var off = TZ.TimezoneService.zoneOffsetMinutes(modelData.zone, TZ.TimezoneService.now)
                                if (gridRoot.hoverCol >= 0)
                                    return TZ.TimezoneService.timeAtOffset(
                                        gridRoot.dayStart + gridRoot.hoverCol * 3600000, off)
                                return TZ.TimezoneService.timeIn(modelData.zone)
                            }
                            font.family: hostBar.fontFamily; font.pixelSize: 12; font.bold: true
                            color: gridRoot.hoverCol >= 0 ? hostBar.colorAccent
                                                          : hostBar.colorText
                        }
                        Text {
                            text: {
                                var off = TZ.TimezoneService.zoneOffsetMinutes(modelData.zone, TZ.TimezoneService.now)
                                if (modelData.home)
                                    return TZ.TimezoneService.dateAtOffset(off)
                                var diff = TZ.TimezoneService.offsetLabel(modelData.zone)
                                var rowDate = TZ.TimezoneService.dateAtOffset(off)
                                var homeDate = TZ.TimezoneService.dateAtOffset(TZ.TimezoneService.homeOffsetMinutes(TZ.TimezoneService.now))
                                return diff + (rowDate !== homeDate ? "  " + rowDate : "")
                            }
                            font.family: hostBar.fontFamily; font.pixelSize: 8
                            color: hostBar.colorTextDim
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // 24 hour cells
                Row {
                    x: gridRoot.headerW + 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Repeater {
                        model: 24
                        Rectangle {
                            width: gridRoot.cellW; height: gridRoot.cellH
                            radius: 3
                            readonly property var c: TZ.TimezoneService.cellAt(
                                index, gridRoot.dayStart,
                                TZ.TimezoneService.zoneOffsetMinutes(modelData.zone, TZ.TimezoneService.now))
                            readonly property bool hot: index === gridRoot.hoverCol
                            color: c.tint === "work" ? Qt.alpha(hostBar.colorAccent, hot ? 0.50 : 0.28)
                                                 : c.tint === "day"  ? Qt.alpha(hostTheme.colors.text, hot ? 0.24 : 0.10)
                                                 : Qt.alpha(hostTheme.colors.text, hot ? 0.16 : 0.035)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 0.85
                                text: parent.c.isMidnight ? parent.c.dayLabel.replace(" ", "\n")
                                                          : String(parent.c.hour)
                                font.family: hostBar.fontFamily
                                font.pixelSize: parent.c.isMidnight ? 6 : 8
                                font.bold: parent.c.isMidnight
                                color: parent.c.isMidnight || parent.c.tint !== "night"
                                       ? hostBar.colorText
                                       : hostBar.colorTextDim
                            }
                        }
                    }
                }
            }
        }
    }

    // "Now" line across all rows
    Rectangle {
        x: gridRoot.headerW + 12 + gridRoot.nowCol * (gridRoot.cellW + 1) - 1
        y: -2
        width: 2
        height: gridRoot.implicitHeight - 18 + 4
        radius: 1
        color: hostBar.colorAccent
        opacity: 0.9
    }

    // Hover-a-column conversion
    MouseArea {
        x: gridRoot.headerW + 12
        y: 0
        width: gridRoot.stripW
        height: gridRoot.implicitHeight - 18
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: console.log("[nikos.timezones] strip hovered")
        onPositionChanged: function(mouse) {
            gridRoot.hoverCol = Math.max(0, Math.min(23, Math.floor(mouse.x / (gridRoot.cellW + 1))))
        }
        onExited: gridRoot.hoverCol = -1
    }

    // Helper line
    Text {
        anchors.top: rows.bottom
        anchors.topMargin: 2
        anchors.left: parent.left
        text: gridRoot.hoverCol >= 0
              ? "hover: " + TZ.TimezoneService.timeAtOffset(
                    gridRoot.dayStart + gridRoot.hoverCol * 3600000,
                    TZ.TimezoneService.homeOffsetMinutes(TZ.TimezoneService.now)) + " your time"
              : "hover a column to convert times"
        font.family: hostBar.fontFamily; font.pixelSize: 8
        color: hostBar.colorTextDim
    }
}
