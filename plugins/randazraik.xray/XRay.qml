import QtQuick
import Quickshell
import "ui"

Item {
    id: root
    objectName: "xrayEntry"

    property var ctx: null
    property var manifest: null
    property alias opened: overlay.opened
    property alias shown: overlay.opened   // host exclusivity contract

    function open(payloadJson) {
        overlay.open(payloadJson || "{}");
    }

    function close() {
        overlay.close();
    }

    function toggle(payloadJson) {
        opened ? close() : open(payloadJson || "{}");
    }

    function browse() {
        overlay.browse();
    }

    function details(domain) {
        overlay.showDetails(String(domain || ""));
    }

    XRayOverlay {
        id: overlay
        ctx: root.ctx
        // Omarchy's app browser has no velocity equivalent; IdentityBar
        // falls back to plain names without it.
        appLibrary: null
    }
}
