// Nerd Font glyph map for the WireGuard plugin (ported from ngeran's
// Commons.I icons). ASTRAL PUA code points — always "\u{…}" escapes, never
// raw glyphs (invisible in editors/diffs). Every code point below was
// verified present in JetBrainsMono Nerd Font (fontTools cmap probe,
// 2026-11-16) — ctx.bar.fontNerd is exactly that face.
const GLYPHS = {
    // bar pill + tunnel state
    shield: "\u{f0498}",          // nf-md-shield — a tunnel is up
    shieldCheck: "\u{f02f6}",     // nf-md-shield-check — active tunnel row
    lock: "\u{f033e}",            // nf-md-lock — everything down (bar pill)
    lockOutline: "\u{f0338}",     // nf-md-lock-outline — idle tunnel row
    key: "\u{f0132}",             // nf-md-key — peer/public key rows
    // traffic
    arrowUp: "\u{f016b}",         // nf-md-arrow-up — tx
    arrowDown: "\u{f016d}",       // nf-md-arrow-down — rx
    earth: "\u{f04df}",           // nf-md-earth — endpoint / internet
    lan: "\u{f0210}",             // nf-md-lan — allowed IPs / interface
    // tailscale pane
    accountNetwork: "\u{f006d}",  // nf-md-account-network — self / device
    globe: "\u{f04df}",           // nf-md-earth — exit node list
    lanConnect: "\u{f059f}",      // nf-md-lan-connect — tailscale hero (source parity)
    // actions / status
    importConf: "\u{f039a}",      // nf-md-file-import-outline — .conf import button (source parity)
    plus: "\u{f01b0}",            // nf-md-plus — import button
    cancel: "\u{f0955}",          // nf-md-cancel — delete / disconnect
    check: "\u{f0156}",           // nf-md-check — success flash
    alert: "\u{f0054}",           // nf-md-alert — error rows
    openInNew: "\u{f01c5}",       // nf-md-open-in-new — auth URL
    contentSave: "\u{f0493}",     // nf-md-content-save — imported profile
    refresh: "\u{f0450}",         // nf-md-refresh — manual refresh
    magnify: "\u{f01fe}"          // nf-md-magnify — search/lookup
};

// Lookup with a silent miss (empty string) so a bad name can never render a
// tofu box in the bar font.
export function glyph(name) {
    return GLYPHS[name] || "";
}
