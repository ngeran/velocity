// privacy.test.mjs — classification rules against real-world node shapes.
import { strict as assert } from "node:assert"
import { classifyLink, surveyPrivacy, activeCount, appNameFor, pidFor } from "./privacy.mjs"

let n = 0
function ok(name, fn) { fn(); n++; console.log("  ok " + name) }

// Realistic node shapes (props trimmed to what the rules read)
const USB_MIC = {
  mediaClass: "Audio/Source", name: "alsa_input.usb-Blue_Microphonesetect-00.analog-stereo",
  description: "Blue Microphones Analog Stereo", props: {},
}
const SINK_MONITOR = {
  mediaClass: "Audio/Source", name: "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor",
  description: "Monitor of Built-in Audio Analog Stereo", props: {},
}
const CAMERA = {
  mediaClass: "Video/Source", name: "v4l2_input.platform-1080.camera",
  description: "Integrated Camera: Integrated C", props: {},
}
const SCREENCAST = {
  mediaClass: "Video/Source", name: "Msigdev-node", description: "DP-1", props: {},
}
const MIC_CAPTURE = {
  mediaClass: "Stream/Input/Audio", name: "firefox", description: "",
  props: { "application.name": "Firefox", "application.process.id": "4242" },
}
const CAM_CAPTURE = {
  mediaClass: "Stream/Input/Video", name: "obs", description: "",
  props: { "application.name": "OBS Studio", "application.process.id": "700" },
}
const SCR_CAPTURE = {
  mediaClass: "Stream/Input/Video", name: "xdg-desktop-portal", description: "",
  props: { "application.name": "xdg-desktop-portal", "application.process.id": "910" },
}
const PLAYBACK = {
  mediaClass: "Stream/Output/Audio", name: "spotify", description: "",
  props: { "application.name": "Spotify" },
}
const SINK = { mediaClass: "Audio/Sink", name: "alsa_output.pci-0000", description: "Built-in", props: {} }

// ── classifyLink ────────────────────────────────────────────────────────────
ok("mic capture from a real mic source", () => {
  assert.equal(classifyLink(USB_MIC, MIC_CAPTURE), "mic")
})
ok("audio capture from a monitor source is screen (system audio)", () => {
  assert.equal(classifyLink(SINK_MONITOR, MIC_CAPTURE), "screen")
})
ok("video capture from a v4l2/camera source is camera", () => {
  assert.equal(classifyLink(CAMERA, CAM_CAPTURE), "camera")
})
ok("video capture from a portal/screencast source is screen", () => {
  assert.equal(classifyLink(SCREENCAST, SCR_CAPTURE), "screen")
})
ok("playback streams are nobody's business", () => {
  assert.equal(classifyLink(PLAYBACK, SINK), null)
})
ok("capture stream playing to a sink is not privacy-relevant", () => {
  assert.equal(classifyLink(MIC_CAPTURE, SINK), null)
})
ok("missing endpoints classify as nothing", () => {
  assert.equal(classifyLink(null, MIC_CAPTURE), null)
  assert.equal(classifyLink(USB_MIC, null), null)
})

// ── surveyPrivacy ───────────────────────────────────────────────────────────
ok("survey buckets by kind with app + pid from the stream", () => {
  const nodes = { 1: USB_MIC, 2: MIC_CAPTURE, 3: CAMERA, 4: CAM_CAPTURE }
  const survey = surveyPrivacy(nodes, [
    { sourceId: 1, targetId: 2 },
    { sourceId: 3, targetId: 4 },
  ])
  assert.deepEqual(survey.mic, [{ app: "Firefox", pid: 4242 }])
  assert.deepEqual(survey.camera, [{ app: "OBS Studio", pid: 700 }])
  assert.deepEqual(survey.screen, [])
})
ok("duplicate app+kind across multiple links deduplicates", () => {
  const nodes = { 1: USB_MIC, 2: MIC_CAPTURE }
  const survey = surveyPrivacy(nodes, [
    { sourceId: 1, targetId: 2 }, { sourceId: 1, targetId: 2 },
  ])
  assert.equal(survey.mic.length, 1)
})
ok("stream without application.name falls back to source then node name", () => {
  const anonymous = { mediaClass: "Stream/Input/Audio", name: "", description: "", props: {} }
  const survey = surveyPrivacy(
    { 1: USB_MIC, 2: anonymous },
    [{ sourceId: 1, targetId: 2 }])
  assert.equal(survey.mic[0].app, "Blue Microphones Analog Stereo")
})
ok("pid parses only real integers", () => {
  assert.equal(pidFor({ props: { "application.process.id": "4242" } }), 4242)
  assert.equal(pidFor({ props: {} }), null)
  assert.equal(pidFor(null), null)
})
ok("appNameFor prefers application.name over node name", () => {
  assert.equal(appNameFor(MIC_CAPTURE), "Firefox")
  assert.equal(appNameFor(null), "")
})

// ── activeCount ─────────────────────────────────────────────────────────────
ok("activeCount sums all kinds", () => {
  assert.equal(activeCount({ mic: [{}], camera: [{}, {}], screen: [] }), 3)
  assert.equal(activeCount(null), 0)
})

console.log("privacy: " + n + " assertions passed")
