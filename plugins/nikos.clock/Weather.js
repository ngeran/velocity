// =============================================================================
// Weather.js — wttr.in j1 parsing + glyph mapping for the clock plugin.
// Self-contained: the anchor (glyph · temp) and the ATMOSPHERE popup both
// read from this. Same contract the nikos.weather plugin used before it was
// removed. Returns null on any parse failure so callers keep their last
// sample (stale-keep).
// =============================================================================

// wttr condition text → Nerd Font glyph. Text matching because the j1 feed's
// human descriptions are stable; unknown conditions fall back to generic.
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

// Beaufort-ish descriptor for the hero line ("Clear Sky • Moderate Breeze").
function windDescriptor(kmph) {
    var v = parseInt(kmph) || 0
    if (v < 2)   return "Calm"
    if (v < 12)  return "Light Breeze"
    if (v < 20)  return "Moderate Breeze"
    if (v < 29)  return "Fresh Breeze"
    if (v < 39)  return "Strong Wind"
    if (v < 50)  return "Gale"
    return "Storm"
}

// UV index → "3.2 (MOD)" style classification.
function uvFormatted(uv) {
    var v = parseFloat(uv)
    if (isNaN(v)) return ""
    var cls = v < 3 ? "LOW" : v < 6 ? "MOD" : v < 8 ? "HIGH" : v < 11 ? "VHIGH" : "EXTREME"
    return v + " (" + cls + ")"
}

// j1 JSON (wttr.in/?format=j1) → structured weather for anchor + popup.
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
            var names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            // Wettest slot of the day drives the "70% rain" outlook line.
            var rain = 0
            for (var i = 0; i < h.length; i++) {
                var c = parseInt(h[i].chanceofrain)
                if (!isNaN(c) && c > rain) rain = c
            }
            return {
                label: isNaN(day.getTime()) ? "--" : names[day.getDay()],
                min: parseInt(w.mintempC), max: parseInt(w.maxtempC),
                desc: desc, glyph: glyphForCondition(desc),
                rain: isNaN(rain) ? 0 : rain
            }
        })

        // "Now" slot for the popup's UV / dew point — nearest 3-hourly block.
        var nowH = Math.min(7, Math.max(0, Math.round(new Date().getHours() / 3)))
        var slot = ((j.weather || [])[0] || {}).hourly
        var cur = slot ? (slot[nowH] || slot[0] || {}) : {}

        return {
            location: (j.nearest_area && j.nearest_area[0])
                      ? j.nearest_area[0].areaName[0].value : "",
            region: (j.nearest_area && j.nearest_area[0] && j.nearest_area[0].region)
                    ? j.nearest_area[0].region[0].value : "",
            temp: (cc.temp_C || "0") + "°C",
            feels: (cc.FeelsLikeC || "0") + "°C",
            humidity: (cc.humidity || "0") + "%",
            wind: (cc.windspeedKmph || "0") + " km/h " + (cc.winddir16Point || ""),
            windDesc: windDescriptor(cc.windspeedKmph),
            condition: (cc.weatherDesc || [{}])[0].value || "",
            pressure: (cc.pressure || "") !== "" ? cc.pressure + " hPa" : "",
            dewPoint: (cur.DewPointC || "") !== "" ? cur.DewPointC + "°C" : "",
            uv: uvFormatted(cur.uvIndex),
            days: days
        }
    } catch (e) { return null }
}
