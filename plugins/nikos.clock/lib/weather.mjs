// Pure weather model: parses Open-Meteo + ipwho.is responses, maps WMO weather
// codes to glyphs and condition labels, and formats temperature. No QML and no
// network here, so the WeatherService singleton stays a thin fetch wrapper and
// node can exercise the parsing (weather.test.mjs beside the synced copy).
// Avoids Date.now()/Math.random() (both throw in the Quickshell JS engine);
// Math.round and the Date constructor are fine (the Calendar uses them).
//
// Glyph/label tables and the parse shapes are adapted from upstream Ryoku's
// services/lib/weather.js (MIT); the IP-locate parse is reshaped for
// ipwho.is, whose field names differ from the ip-api form.

// WMO weather code -> a Nerd Font weather glyph (the mono set drawn inline
// with the calendar's text, where a Material icon would not share the run).
// Day/night split where the font has both faces; an unknown code falls back
// to the neutral cloud.
function nerdFor(code, isDay) {
    var day = isDay === undefined ? true : !!isDay;
    if (code === 0) return day ? "\ue30d" : "\ue32b";
    if (code === 1 || code === 2) return day ? "\ue302" : "\ue32e";
    if (code === 3) return "\ue33d";
    if (code === 45 || code === 48) return "\ue313";
    if (code >= 95 && code <= 99) return "\ue31d";
    if (code === 85 || code === 86) return "\ue31a";
    if (code >= 71 && code <= 77) return "\ue3ad";
    if (code >= 80 && code <= 82) return day ? "\ue308" : "\ue333";
    if (code === 66 || code === 67) return "\ue318";
    if (code >= 61 && code <= 65) return day ? "\ue30a" : "\ue327";
    if (code >= 51 && code <= 57) return day ? "\ue308" : "\ue333";
    return "\ue33d";
}

// Short condition word for a WMO code.
function labelFor(code) {
    if (code === 0) return "Clear";
    if (code <= 3) return "Cloudy";
    if (code === 45 || code === 48) return "Fog";
    if (code >= 95) return "Thunder";
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow";
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "Rain";
    return "Cloudy";
}

// Imperial vs metric from the locale env, so a US locale keeps Fahrenheit.
// US, Liberia and Myanmar are the Fahrenheit holdouts.
function unitFor(localeEnv) {
    var l = String(localeEnv || "");
    return /(^|[_.@-])(US|LR|MM)([_.@-]|$)/.test(l) ? "fahrenheit" : "celsius";
}

function tempSymbol(unit) { return unit === "fahrenheit" ? "°F" : "°C"; }

// "27°C" / "81°F". The temperature is already in `unit` (it is what we request
// from Open-Meteo), so this only rounds and appends the symbol.
function formatTemp(temp, unit) {
    return Math.round(temp) + tempSymbol(unit);
}

// Parse an Open-Meteo forecast into the panel's weather state. Guards every
// field: a missing/!numeric current block yields available:false so the panel
// keeps its last good values. `daily` is truncated by the REQUEST
// (forecast_days), not here — everything the server sent is kept.
function parseForecast(json, unit) {
    var out = {
        available: false, tempNow: 0, temp: "", condition: "", humidity: 0,
        feels: 0, isDay: true, code: 0, hourly: [], daily: []
    };
    var cur = json && json.current;
    if (!cur || typeof cur.temperature_2m !== "number" || typeof cur.weather_code !== "number")
        return out;

    var h = json.hourly;
    if (h && h.time && h.temperature_2m && h.weather_code) {
        var n = Math.min(h.time.length, h.temperature_2m.length, h.weather_code.length);
        for (var i = 0; i < n; i++)
            out.hourly.push({
                t: String(h.time[i]),                                   // "2026-10-25T22:00" (timezone=auto → local naive)
                hour: String(h.time[i]).slice(11, 13),
                temp: Math.round(h.temperature_2m[i]),
                code: h.weather_code[i],
                precip: (h.precipitation_probability && typeof h.precipitation_probability[i] === "number") ? h.precipitation_probability[i] : 0,
                isDay: (h.is_day && typeof h.is_day[i] === "number") ? h.is_day[i] === 1 : true
            });
    }

    var d = json.daily;
    if (d && d.time && d.weather_code && d.temperature_2m_max && d.temperature_2m_min) {
        var dn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var m = Math.min(d.time.length, d.weather_code.length, d.temperature_2m_max.length, d.temperature_2m_min.length);
        for (var j = 0; j < m; j++) {
            var p = String(d.time[j]).split("-");
            var dow = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])).getDay();
            out.daily.push({ day: dn[dow], code: d.weather_code[j], hi: Math.round(d.temperature_2m_max[j]), lo: Math.round(d.temperature_2m_min[j]) });
        }
    }

    out.tempNow = Math.round(cur.temperature_2m);
    out.temp = formatTemp(cur.temperature_2m, unit);
    out.code = cur.weather_code;
    out.condition = labelFor(cur.weather_code);
    out.humidity = typeof cur.relative_humidity_2m === "number" ? Math.round(cur.relative_humidity_2m) : 0;
    out.feels = typeof cur.apparent_temperature === "number" ? Math.round(cur.apparent_temperature) : 0;
    out.wind = typeof cur.wind_speed_10m === "number" ? Math.round(cur.wind_speed_10m) : 0;
    out.isDay = cur.is_day === 1;
    out.available = true;
    return out;
}

// Parse ipwho.is's response to { city, lat, lon }, or null when it failed.
// (Field names differ from ip-api: latitude/longitude, success:true.)
function parseIpwho(json) {
    if (json && json.success === true
        && typeof json.latitude === "number" && typeof json.longitude === "number")
        return { city: json.city || "", lat: json.latitude, lon: json.longitude };
    return null;
}

// Parse Open-Meteo's geocoding response to { city, lat, lon }, or null when
// the query matched nothing.
function parseGeo(json) {
    if (!json || !Array.isArray(json.results) || json.results.length === 0)
        return null;
    var r = json.results[0];
    if (typeof r.latitude !== "number" || typeof r.longitude !== "number")
        return null;
    return { city: r.name || "", lat: r.latitude, lon: r.longitude };
}

// The hour cards' slice: rows from the CURRENT hour on (today-card curve
// starts at "now", like upstream's). `nowStr` is the local naive stamp's
// first 13 chars ("yyyy-MM-ddTHH") to compare against row.t's prefix.
// Falls back to the LAST n rows when nothing is ahead (clock skew, stale
// cache) so the curve always has points to draw.
function sliceAhead(hourly, nowStr, n) {
    if (!hourly || hourly.length === 0) return [];
    var start = -1;
    for (var i = 0; i < hourly.length; i++) {
        if (String(hourly[i].t || "").slice(0, 13) >= nowStr) { start = i; break }
    }
    if (start === -1) start = Math.max(0, hourly.length - n);
    return hourly.slice(start, start + n);
}

// Guarded JSON.parse: null on any empty or malformed body.
function parseJson(text) {
    try {
        if (text && text.trim().length > 0) return JSON.parse(text);
    } catch (e) {}
    return null;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { nerdFor, labelFor, unitFor, tempSymbol, formatTemp, parseForecast, parseIpwho, parseGeo, parseJson, sliceAhead };
}

export { nerdFor, labelFor, unitFor, tempSymbol, formatTemp, parseForecast, parseIpwho, parseGeo, parseJson, sliceAhead };
