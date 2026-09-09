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

// =============================================================================
// j1 JSON (wttr.in/?format=j1) → structured weather for the TrayCard popup.
// Returns null on any parse failure so the service can keep its last sample.
// =============================================================================
function parseJ1(raw) {
    try {
        var j = JSON.parse(String(raw || "{}"))
        var cc = (j.current_condition || [])[0]
        if (!cc || cc.temp_C === undefined) return null

        // 3-hourly slots: index 4 = 12:00 (best representative glyph per day)
        var days = (j.weather || []).slice(0, 3).map(function(w) {
            var h = w.hourly || []
            var noon = h[4] || h[0] || {}
            var desc = (noon.weatherDesc || [])[0] ? noon.weatherDesc[0].value
                     : ((w.weatherDesc || [])[0] ? w.weatherDesc[0].value : "")
            var day = new Date(String(w.date || "") + "T00:00:00")
            var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            return {
                label: isNaN(day.getTime()) ? "--" : names[day.getDay()],
                min: parseInt(w.mintempC), max: parseInt(w.maxtempC),
                desc: desc, glyph: glyphForCondition(desc)
            }
        })

        return {
            location: (j.nearest_area && j.nearest_area[0])
                      ? j.nearest_area[0].areaName[0].value : "",
            temp: (cc.temp_C || "0") + "°C",
            feels: (cc.FeelsLikeC || "0") + "°C",
            humidity: (cc.humidity || "0") + "%",
            wind: (cc.windspeedKmph || "0") + " km/h " + (cc.winddir16Point || ""),
            condition: (cc.weatherDesc || [{}])[0].value || "",
            days: days
        }
    } catch (e) { return null }
}

if (typeof module !== "undefined") {
    module.exports.parseJ1 = parseJ1
}
