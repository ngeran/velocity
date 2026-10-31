// VolumeIcon.qml — volume glyph; hover reveals "VOL n%"; click opens the tray.
// Scroll adjusts volume even when the card is closed (OSD feedback kept).
// The hover-pill shell is the shared HoverGlyph base (DU10).
import QtQuick
import bar.services as Services
import bar.config as Config

HoverGlyph {
    id: root

    glyph: Services.AudioService.muted ? "󰝟"
           : (Services.AudioService.volume > 50 ? "󰕾" : "󰕿")
    label: Services.AudioService.muted ? "MUTED"
           : "VOL " + Math.round(Services.AudioService.volume) + "%"

    signal trayRequested()
    onTriggered: root.trayRequested()

    // Scroll to change volume even when the card is closed.
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y > 0) Services.AudioService.volumeUp()
            else Services.AudioService.volumeDown()
            Services.OsdService.showVolume(Services.AudioService.volume, Services.AudioService.muted)
        }
    }
}
