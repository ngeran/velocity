// =============================================================================
// Weather.js — minimal wttr.in j1 parse for the clock anchor (self-contained).
// The standalone nikos.weather plugin was removed; the anchor only needs the
// condition glyph + temperature, so this is the whole contract.
// =============================================================================

// wttr condition text → Nerd Font glyph (same mapping the weather plugin used).
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

// Returns null on any parse failure so the caller keeps its last sample.
function parseJ1(raw) {
    try {
        var j = JSON.parse(String(raw || "{}"))
        var cc = (j.current_condition || [])[0]
        if (!cc || cc.temp_C === undefined) return null
        var desc = (cc.weatherDesc || [{}])[0].value || ""
        return {
            temp: (cc.temp_C || "0") + "°C",
            condition: desc,
            glyph: glyphForCondition(desc)
        }
    } catch (e) { return null }
}
