import QtQuick
Item {
    id: root
    property string moduleName: ""
    property var api: null
    property var bar: root.api ? ({
        shell: {
            toggle: function(name, payload) {
                if (root.api.host) root.api.host.requestTogglePanel(name)
                return "ok"
            },
            summon: function(name, payload) {
                if (root.api.host) root.api.host.requestTogglePanel(name)
                return "ok"
            }
        }
    }) : null
    implicitWidth: 10
    implicitHeight: 10
}
