// =============================================================================
// WeatherModel.js — pure wttr.in one-liner parsing + glyph mapping
// =============================================================================
// No Qt imports (Node-testable via the module.exports guard — same convention
// as NetworkModel.js / NetworkControlModel.js).
// =============================================================================

// "Malvern, Pennsylvania, US|+25°C|Clear" → {location, temp, condition}.
// Mirrors the settings WeatherCard guard: only a line whose temp field
// contains "°" is accepted (wttr error pages don't), so callers can keep the
// last good sample on failure. The redundant "+" prefix is stripped.
function parseWeatherLine(line) {
    var f = String(line || "").trim().split("|")
    if (f.length < 3) return null
    var temp = f[1].trim()
    if (temp.indexOf("°") === -1) return null
    return {
        location: f[0].trim(),
        temp: temp.replace(/^\+/, ""),
        condition: f[2].trim()
    }
}

// wttr condition text → Nerd Font glyph. Text matching (not the j1 numeric
// codes) because the bar fetches the cheap one-liner format; unknown
// conditions fall back to the generic cloud glyph.
function glyphForCondition(cond) {
    var s = String(cond || "").toLowerCase()
    if (/thunder/.test(s))                    return "󰖓"
    if (/snow|sleet|ice pellet|blizzard/.test(s)) return "󰼶"
    if (/rain|drizzle|shower/.test(s))        return "󰖖"
    if (/fog|mist|haze/.test(s))              return "󰖑"
    if (/sun|clear/.test(s))                  return "󰖙"
    if (/cloud|overcast/.test(s))             return "󰖔"
    return "󰖐"
}

if (typeof module !== "undefined") {
    module.exports = {
        parseWeatherLine: parseWeatherLine,
        glyphForCondition: glyphForCondition
    }
}
