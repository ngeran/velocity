// Nerd Font glyph map for the VNC plugin. ASTRAL PUA code points — always
// "\u{…}" escapes, never raw glyphs (invisible in editors/diffs). Every code
// point below was verified present in JetBrainsMono Nerd Font (fontTools
// cmap probe, 2026-11-20) — ctx.bar.fontNerd is exactly that face.
const GLYPHS = {
    // bar pill + session state
    monitor: "\u{f0379}",          // nf-md-monitor — idle / viewer not running
    monitorCheck: "\u{f12b7}",     // nf-md-monitor-check — viewer connected
    monitorOff: "\u{f0378}",       // nf-md-monitor-off — host unreachable
    apple: "\u{f0035}",            // nf-md-apple — popup title
    // probes + telemetry
    lanConnect: "\u{f059f}",       // nf-md-lan-connect — VNC port open / CONNECT
    lanDisconnect: "\u{f059c}",    // nf-md-lan-disconnect — VNC port closed
    chartLine: "\u{f012d}",        // nf-md-chart-line — sparkline header
    timerOutline: "\u{f051b}",    // nf-md-timer-outline — session duration
    earth: "\u{f04df}",            // nf-md-earth — ICMP probe row
    key: "\u{f0132}",              // nf-md-key — auth hint row
    // actions
    refresh: "\u{f0450}",          // nf-md-refresh — manual refresh
    // saved-connection list + form (v2)
    pencil: "\u{f03cb}",           // nf-md-pencil — edit connection
    trashCan: "\u{f05ab}",         // nf-md-trash-can — delete (with confirm)
    plus: "\u{f0415}",             // nf-md-plus — add connection
    close: "\u{f0156}",            // nf-md-close — cancel / collapse form
    contentSave: "\u{f013a}",      // nf-md-content-save — save & connect
    check: "\u{f012c}",            // nf-md-check — save
    eye: "\u{f06d4}",              // nf-md-eye — password revealed
    eyeOff: "\u{f06d1}"            // nf-md-eye-off — password hidden
};

// Lookup with a silent miss (empty string) so a bad name can never render a
// tofu box in the bar font.
export function glyph(name) {
    return GLYPHS[name] || "";
}
