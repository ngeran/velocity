// privacy.mjs — pure logic for the privacy pill: PipeWire link graph →
// what is watching/listening, and through which app.
//
// Input is plain data extracted from Quickshell's native Pipewire service
// (PrivacyService): nodes keyed by id, and active link groups as
// { sourceId, targetId }. Classification mirrors the standard semantics —
// media.class tells capture ("Stream/Input/*") from playback ("Stream/Output/*"),
// the SOURCE node tells what is being captured:
//   audio capture from a mic-like source      -> mic
//   audio capture from a monitor/virtual src  -> screen (system-audio capture)
//   video capture from a camera-ish source    -> camera
//   video capture from anything else          -> screen (portal screencast)
//
// Kept out of QML so the rules are unit-testable against real-world
// node property shapes (privacy.test.mjs).

// Node data: { mediaClass, name, description, props }
// props is the raw properties map (application.name, application.process.id, …)

function isCaptureStream(node) {
  var mc = node.mediaClass || ""
  return mc.indexOf("Stream/Input/") === 0
}

function looksLikeMonitor(node) {
  var hay = ((node.name || "") + " " + (node.description || "")).toLowerCase()
  return hay.indexOf("monitor") !== -1 || hay.indexOf("virtual") !== -1
}

function looksLikeCamera(node) {
  var hay = ((node.name || "") + " " + (node.description || "")).toLowerCase()
  return hay.indexOf("camera") !== -1 || hay.indexOf("webcam") !== -1 ||
         hay.indexOf("v4l2") !== -1 || hay.indexOf("uvc") !== -1
}

// "mic" | "camera" | "screen" | null for one active link group.
// Only capture streams count — a sink playing music is nobody's business.
export function classifyLink(source, target) {
  if (!source || !target || !isCaptureStream(target)) return null
  var video = (target.mediaClass || "") === "Stream/Input/Video"
  if (video) return looksLikeCamera(source) ? "camera" : "screen"
  return looksLikeMonitor(source) ? "screen" : "mic"
}

// Best human name for the app behind a capture stream. Streams usually carry
// application.name; bare nodes fall back to their own name.
export function appNameFor(node) {
  if (!node) return ""
  var p = node.props || {}
  return p["application.name"] || p["application.process.binary"] ||
         node.name || node.description || ""
}

// Human name for a DEVICE node (source side) — alsa/pipewire `name` is an id
// string ("alsa_input.usb-…"), `description` is what a person reads.
export function deviceNameFor(node) {
  if (!node) return ""
  var p = node.props || {}
  return p["application.name"] || node.description || node.name || ""
}

export function pidFor(node) {
  if (!node) return null
  var raw = (node.props || {})["application.process.id"]
  var pid = parseInt(raw, 10)
  return (pid && !isNaN(pid)) ? pid : null
}

// nodes: { id: nodeData }, links: [{ sourceId, targetId }]
// → { mic: [{app, pid}], camera: [...], screen: [...] }, deduplicated by
// (kind, app, pid), insertion order preserved (registry order is stable).
export function surveyPrivacy(nodes, links) {
  var out = { mic: [], camera: [], screen: [] }
  var seen = {}
  for (var i = 0; i < links.length; i++) {
    var kind = classifyLink(nodes[links[i].sourceId], nodes[links[i].targetId])
    if (!kind) continue
    var stream = nodes[links[i].targetId]
    var app = appNameFor(stream)
    if (!app) app = deviceNameFor(nodes[links[i].sourceId])
    var pid = pidFor(stream)
    var key = kind + "|" + app + "|" + pid
    if (seen[key]) continue
    seen[key] = true
    out[kind].push({ app: app, pid: pid })
  }
  return out
}

// Total distinct active uses — drives the pill's visibility and dot count.
export function activeCount(survey) {
  if (!survey) return 0
  return (survey.mic ? survey.mic.length : 0) +
         (survey.camera ? survey.camera.length : 0) +
         (survey.screen ? survey.screen.length : 0)
}
