// qs.Ui/Util.qml — shell helpers for compat plugins.
pragma Singleton
import QtQuick

QtObject {
    function shellQuote(s) {
        return "'" + String(s === null || s === undefined ? "" : s).replace(/'/g, "'\\''") + "'"
    }
    function plainText(s) {
        return String(s === null || s === undefined ? "" : s).replace(/[<>&]/g, "")
    }
}
