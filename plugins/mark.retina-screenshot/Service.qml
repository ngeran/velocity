import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property string pendingMode: "--region"
  readonly property bool busy: captureDelay.running || captureProcess.running

  readonly property string scriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("scripts/retina-screenshot")).replace(/^file:\/\//, ""))

  // The engine's fail() only prints to stderr and no notify-send exists on
  // this system — surface problems as a Hyprland toast instead, so a click
  // can never fail silently again.
  function toast(message, isError) {
    notifyProc.command = ["hyprctl", "notify",
      isError ? "3" : "1", "5000",
      isError ? "0xff6b6b" : "0x9ece6a",
      " Retina Screenshot: " + message]
    notifyProc.running = true
  }

  Process { id: notifyProc; command: [] }

  // Preflight: the script aborts before opening the picker when a required
  // binary is absent. One cheap probe per click. wl-copy is NOT blocking —
  // without it the capture degrades to save-only (--no-copy).
  property bool wlCopyAvailable: false

  function startCapture(mode): string {
    if (root.busy) return "busy"
    root.pendingMode = mode
    preflightProc.running = true
    return "started"
  }

  function capture(): string { return root.startCapture("--region") }
  function captureRegion(): string { return root.startCapture("--region") }
  function captureWindow(): string { return root.startCapture("--window") }

  Process {
    id: preflightProc
    command: ["sh", "-c",
      "for t in jq grim slurp hyprctl wl-copy; do command -v \"$t\" >/dev/null 2>&1 || echo \"$t\"; done"]
    property string buffer: ""
    stdout: SplitParser { onRead: function(d) { preflightProc.buffer += d } }
    onRunningChanged: {
      if (running) return
      var missing = preflightProc.buffer.trim()
      preflightProc.buffer = ""
      var blockers = []
      var lines = missing === "" ? [] : missing.split("\n")
      for (var i = 0; i < lines.length; i++) {
        if (lines[i] === "wl-copy") root.wlCopyAvailable = false
        else blockers.push(lines[i])
      }
      if (lines.indexOf("wl-copy") === -1) root.wlCopyAvailable = true
      if (blockers.length > 0) {
        console.log("[retina-screenshot] missing commands: " + blockers.join(", "))
        toast("install " + blockers.join(", ") + " (add to flake)", true)
        return
      }
      captureDelay.restart()
    }
  }

  Process {
    id: captureProcess
    property string errorLine: ""
    property string savedPath: ""
    stderr: SplitParser { onRead: function(d) { captureProcess.errorLine = d } }
    stdout: SplitParser { onRead: function(d) { captureProcess.savedPath = d } }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var msg = String(captureProcess.errorLine || "").replace(/^retina-screenshot:\s*/, "").trim()
        if (msg !== "") {
          console.log("[retina-screenshot] " + msg)
          toast(msg, true)
        }
      } else {
        // Success prints the saved path; a cancelled picker exits 0 silently.
        var path = String(captureProcess.savedPath || "").trim()
        if (path !== "")
          toast("saved " + path.replace(/^.*\/Pictures\//, "~/Pictures/"), false)
      }
      captureProcess.errorLine = ""
      captureProcess.savedPath = ""
    }
  }

  // Let the bar's pointer-release dispatch finish before slurp creates its
  // input-grabbing layer surface. Starting inside the click callback can leave
  // slurp alive after its surface loses the compositor grab.
  Timer {
    id: captureDelay
    interval: 250
    repeat: false
    onTriggered: {
      var args = ["timeout", "--signal=TERM", "--kill-after=3s", "180s",
                  root.scriptPath, root.pendingMode, "--scale", "2"]
      if (!root.wlCopyAvailable) args.push("--no-copy")
      captureProcess.command = args
      captureProcess.running = true
    }
  }

  IpcHandler {
    target: "mark.retina-screenshot"

    function capture(): string { return root.capture() }
    function captureRegion(): string { return root.captureRegion() }
    function captureWindow(): string { return root.captureWindow() }
    function status(): string { return root.busy ? "busy" : "idle" }
  }
}
