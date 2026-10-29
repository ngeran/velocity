// GENERATED from shared/b64.mjs by tools/sync-shared — do not edit
// b64.mjs — base64 WITHOUT Qt.btoa (DU2/DU3: canonical in shared/, synced to
// the roots that import it; pure functions only, node-tested).
//
// Qt 6 deprecates Qt.btoa(string) — the engine logs a warning on EVERY call
// (the steady-state journal spam: 16/min from ArchLogo's hover bindings
// alone pre-P1). The Web-compatible overload isn't exposed to QML, so the
// encode lives here instead. Input is treated Latin-1 (btoa semantics — the
// SVG bodies we encode are ASCII by construction).
const CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

export function b64encode(input) {
    var s = String(input)
    var out = ""
    for (var i = 0; i < s.length; i += 3) {
        var a = s.charCodeAt(i) & 0xff
        var hasB = i + 1 < s.length
        var hasC = i + 2 < s.length
        var b = hasB ? s.charCodeAt(i + 1) & 0xff : 0
        var c = hasC ? s.charCodeAt(i + 2) & 0xff : 0
        out += CHARS[a >> 2]
        out += CHARS[((a & 3) << 4) | (b >> 4)]
        out += hasB ? CHARS[((b & 15) << 2) | (c >> 6)] : "="
        out += hasC ? CHARS[c & 63] : "="
    }
    return out
}
