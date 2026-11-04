// Pure ArtCraft status/progress helpers.
// No QML, no processes, no Date.now()/Math.random() (both are unreliable in
// the Quickshell JS engine). The service and panel only format data here, so
// node can exercise the edge cases in artcraft.test.mjs.

const EMPTY_STATUS = {
    checked: 0,
    count: 0,
    errors: 0,
    error: "",
    apps: [],
    outdated: []
};

const EMPTY_PROGRESS = {
    running: false,
    active: "",
    overall: 0,
    message: "",
    error: "",
    updated: 0,
    apps: {}
};

function obj(v) {
    return v && typeof v === "object" && !Array.isArray(v) ? v : {};
}

function arr(v) {
    return Array.isArray(v) ? v : [];
}

function str(v) {
    return v === null || v === undefined ? "" : String(v);
}

function num(v, fallback) {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
}

function clampPct(v) {
    return Math.max(0, Math.min(100, Math.round(num(v, 0))));
}

function normalizeApp(raw) {
    const a = obj(raw);
    return {
        app: str(a.app),
        displayName: str(a.displayName || a.app),
        repo: str(a.repo),
        installed: str(a.installed),
        latest: str(a.latest),
        url: str(a.url),
        state: str(a.state || "unknown")
    };
}

function normalizeStatus(raw) {
    const s = obj(raw);
    const apps = arr(s.apps).map(normalizeApp);
    const outdated = arr(s.outdated).map(normalizeApp);
    return {
        checked: num(s.checked, 0),
        count: num(s.count, outdated.length),
        errors: num(s.errors, 0),
        error: str(s.error),
        apps: apps,
        outdated: outdated
    };
}

function normalizeProgress(raw) {
    const p = obj(raw);
    const apps = {};
    const source = obj(p.apps);
    for (const key of Object.keys(source)) {
        const a = obj(source[key]);
        apps[key] = {
            phase: str(a.phase || "pending"),
            percent: clampPct(a.percent),
            message: str(a.message)
        };
    }
    return {
        running: p.running === true,
        active: str(p.active),
        overall: clampPct(p.overall),
        message: str(p.message),
        error: str(p.error),
        updated: num(p.updated, 0),
        apps: apps
    };
}

function appProgress(progress, app) {
    const p = normalizeProgress(progress);
    return p.apps[str(app)] || null;
}

function rowState(app, progress) {
    const a = normalizeApp(app);
    const p = appProgress(progress, a.app);
    if (p && p.phase !== "pending") {
        if (p.phase === "done") return "done";
        if (p.phase === "error") return "retry";
        return p.phase;
    }
    if (a.state === "outdated") return "update";
    if (a.state === "current") return "current";
    if (a.state === "waiting") return "waiting";
    if (a.state === "error") return "error";
    return "unknown";
}

function phaseLabel(phase) {
    switch (str(phase)) {
        case "download": return "DOWNLOADING";
        case "hash": return "HASHING";
        case "pin": return "PINNING";
        case "switch": return "REBUILDING";
        case "check": return "CHECKING";
        case "done": return "DONE";
        case "error": return "FAILED";
        case "pending": return "QUEUED";
        default: return "";
    }
}

function versionLabel(v) {
    const s = str(v);
    return s === "" ? "—" : s;
}

function relativeTime(epoch, now) {
    const then = num(epoch, 0);
    const current = num(now, 0);
    if (then <= 0) return "never";
    const seconds = Math.max(0, Math.floor(current - then));
    if (seconds < 45) return "just now";
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return minutes + "m ago";
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return hours + "h ago";
    return Math.floor(hours / 24) + "d ago";
}

function formatPercent(v) {
    return clampPct(v) + "%";
}

export {
    EMPTY_STATUS,
    EMPTY_PROGRESS,
    normalizeApp,
    normalizeStatus,
    normalizeProgress,
    appProgress,
    rowState,
    phaseLabel,
    versionLabel,
    relativeTime,
    formatPercent,
    clampPct
};
