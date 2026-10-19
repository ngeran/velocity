// =============================================================================
// SettingsStore.qml — one plugin's persistent settings (ctx.settings)
// =============================================================================
// One store per plugin id, shared by every instance of that plugin (a bar
// widget exists once per output), so instances never clobber each other.
// File: $XDG_STATE_HOME/velocity/plugins/<id>.json. Values = manifest
// `settings` defaults overlaid with the stored file (lib/settings.mjs
// merge/coerce). The file is watched, so external edits (settings app, CLI,
// a text editor) land live.
//
//   ctx.settings.values.city          — bindable
//   ctx.settings.get("city", "x")
//   ctx.settings.set("city", "Tokyo") → true, or false if it fails the schema
//   onSettingChanged: function(key) { … }
// =============================================================================

import QtQuick
import Quickshell.Io
import "lib/settings.mjs" as Schema

Item {
    id: store
    visible: false

    property string pluginId: ""
    property var schema: ({})
    property string path: ""

    property var values: Schema.defaultsFor(schema)
    signal settingChanged(string key)

    function get(key, fallback) {
        var v = store.values[key]
        return v === undefined ? fallback : v
    }

    function set(key, value) {
        var k = String(key)
        var v = value
        if (store.schema && store.schema[k] !== undefined) {
            var c = Schema.coerce(store.schema[k], value)
            if (!c.ok) {
                console.warn("[" + store.pluginId + "] setting '" + k + "' rejected: " + c.error)
                return false
            }
            v = c.value
        }
        var next = Object.assign({}, store.values)
        next[k] = v
        store._apply(next)
        store._write()
        return true
    }

    // Replace values, signalling only the keys that actually changed.
    function _apply(next) {
        var keys = Schema.changedKeys(store.values, next)
        store.values = next
        for (var i = 0; i < keys.length; i++) store.settingChanged(keys[i])
    }

    FileView {
        id: file
        path: store.path
        watchChanges: true
        printErrors: false
        onLoaded: {
            var stored = {}
            try { stored = JSON.parse(text() || "{}") } catch (e) {
                console.warn("[" + store.pluginId + "] settings file is not valid JSON — using defaults")
            }
            store._apply(Schema.merge(store.schema, stored))
        }
        onLoadFailed: store._apply(Schema.defaultsFor(store.schema))
        onFileChanged: reload()
    }
    onPathChanged: if (path !== "") file.reload()

    // Single writer per id; a write requested while one runs is coalesced
    // into one follow-up with the latest values.
    property bool _dirty: false
    function _write() {
        if (store.path === "") return
        if (writer.running) { store._dirty = true; return }
        writer.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"',
            "sh", store.path, JSON.stringify(store.values, null, 1)]
        writer.running = true
    }
    Process {   // unbounded-ok: one-shot local file write (tmp + mv)
        id: writer
        command: []; running: false
        onExited: function(code) {
            if (code !== 0) console.warn("[" + store.pluginId + "] settings write failed exit=" + code)
            if (store._dirty) { store._dirty = false; store._write() }
        }
    }
}
