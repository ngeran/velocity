import QtQuick

QtObject {
    // MUST match manifest.json "id" — the launcher summons by this id and the
    // host registers the overlay under the manifest id (drift = dead button;
    // upstream's "io.github." prefix was dropped in this port).
    readonly property string pluginId: "randazraik.xray"
    readonly property string layerNamespace: "omarchy-xray"
}
