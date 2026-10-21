pragma Singleton
import QtQuick
QtObject {
    function flat(color, width) {
        return { color: color, width: width === undefined ? 1 : width }
    }
}
