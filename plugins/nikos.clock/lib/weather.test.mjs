// weather.test.mjs — node asserts for the pure weather model (no framework,
// same contract as the engine lib tests). Run via tools/run-unit-tests.
// Expected glyphs are written as \uXXXX escapes (PUA code points are invisible
// in editors and diffs — never paste them raw).
import assert from "node:assert"
import { nerdFor, labelFor, unitFor, tempSymbol, formatTemp, parseForecast, parseIpwho, parseGeo, parseJson, sliceAhead } from "./weather.mjs"

let n = 0
const ok = (name, fn) => { fn(); n++; console.log("  ok " + name) }

// ── WMO tables ─────────────────────────────────────────────────────────────
ok("clear splits day/night", () => {
  assert.equal(nerdFor(0, true), "\ue30d")
  assert.equal(nerdFor(0, false), "\ue32b")
})
ok("partly cloudy splits", () => {
  assert.equal(nerdFor(2, true), "\ue302")
  assert.equal(nerdFor(2, false), "\ue32e")
})
ok("cloud/fog/thunder buckets", () => {
  assert.equal(nerdFor(3), "\ue33d")
  assert.equal(nerdFor(45), "\ue313")
  assert.equal(nerdFor(95), "\ue31d")
  assert.equal(nerdFor(99), "\ue31d")
})
ok("snow bucket (71-77, 85, 86)", () => {
  assert.equal(nerdFor(71), "\ue3ad")
  assert.equal(nerdFor(86), "\ue31a")
})
ok("rain buckets vs showers", () => {
  assert.equal(nerdFor(63, true), "\ue30a")
  assert.equal(nerdFor(63, false), "\ue327")
  assert.equal(nerdFor(81, true), "\ue308")
  assert.equal(nerdFor(81, false), "\ue333")
  assert.equal(nerdFor(66), "\ue318")
})
ok("unknown code falls back to neutral cloud", () => {
  assert.equal(nerdFor(42), "\ue33d")
  assert.equal(nerdFor(undefined), "\ue33d")
})
ok("labels", () => {
  assert.equal(labelFor(0), "Clear")
  assert.equal(labelFor(2), "Cloudy")
  assert.equal(labelFor(48), "Fog")
  assert.equal(labelFor(61), "Rain")
  assert.equal(labelFor(73), "Snow")
  assert.equal(labelFor(95), "Thunder")
})

// ── units ──────────────────────────────────────────────────────────────────
ok("locale unit detection", () => {
  assert.equal(unitFor("en_US.UTF-8"), "fahrenheit")
  assert.equal(unitFor("de_DE.UTF-8"), "celsius")
  assert.equal(unitFor(""), "celsius")
})
ok("temp formatting", () => {
  assert.equal(formatTemp(27.4), "27°C")
  assert.equal(formatTemp(-0.4), "0°C")   // String(-0) === "0" — rounds away, same as upstream
  assert.equal(formatTemp(81, "fahrenheit"), "81°F")
  assert.equal(tempSymbol("fahrenheit"), "°F")
})

// ── parseForecast ──────────────────────────────────────────────────────────
const CAPTURED = {
  current: { temperature_2m: 26.8, relative_humidity_2m: 41, apparent_temperature: 25.1,
             wind_speed_10m: 3.4, weather_code: 2, is_day: 1 },
  hourly: { time: ["2026-10-25T14:00", "2026-10-25T15:00"],
            temperature_2m: [26.8, 27.2], weather_code: [2, 1],
            precipitation_probability: [10, 5],
            is_day: [1, 1] },
  daily: { time: ["2026-10-25", "2026-10-26", "2026-10-27"],
           weather_code: [2, 61, 0],
           temperature_2m_max: [27.9, 22.3, 24.0],
           temperature_2m_min: [17.2, 15.1, 14.0] }
}
ok("full parse", () => {
  const w = parseForecast(CAPTURED, "celsius")
  assert.equal(w.available, true)
  assert.equal(w.tempNow, 27)
  assert.equal(w.temp, "27°C")
  assert.equal(w.condition, "Cloudy")
  assert.equal(w.code, 2)   // service needs the raw code for the day/night glyph
  assert.equal(w.isDay, true)
  assert.equal(w.feels, 25)
  assert.equal(w.humidity, 41)
  assert.equal(w.wind, 3)   // today-card metric tile
  assert.equal(w.hourly.length, 2)
  assert.equal(w.hourly[0].hour, "14")
  assert.equal(w.hourly[0].t, "2026-10-25T14:00")
  assert.equal(w.hourly[0].isDay, true)
  assert.equal(w.hourly[1].precip, 5)
  assert.equal(w.daily.length, 3)
  assert.equal(w.daily[0].hi, 28)
  assert.equal(w.daily[0].lo, 17)
  assert.equal(typeof w.daily[1].day, "string")
})
ok("missing current block -> available:false", () => {
  assert.equal(parseForecast({}, "celsius").available, false)
  assert.equal(parseForecast(null, "celsius").available, false)
  assert.equal(parseForecast({ current: { temperature_2m: "x" } }, "celsius").available, false)
})
ok("partial hourly/daily tolerated", () => {
  const w = parseForecast({ current: { temperature_2m: 1, weather_code: 0, is_day: 0 } }, "celsius")
  assert.equal(w.available, true)
  assert.equal(w.isDay, false)
  assert.deepEqual(w.hourly, [])
  assert.deepEqual(w.daily, [])
})
ok("missing precip probability defaults 0", () => {
  const w = parseForecast({ current: { temperature_2m: 1, weather_code: 0 },
    hourly: { time: ["2026-10-25T14:00"], temperature_2m: [1], weather_code: [0] } }, "celsius")
  assert.equal(w.hourly[0].precip, 0)
})

// ── sliceAhead (hourly curve) ──────────────────────────────────────────────
const HRS = [
  { t: "2026-10-25T20:00", temp: 1 },
  { t: "2026-10-25T21:00", temp: 2 },
  { t: "2026-10-25T22:00", temp: 3 },
  { t: "2026-10-25T23:00", temp: 4 },
  { t: "2026-10-26T00:00", temp: 5 }
]
ok("sliceAhead starts at the current hour, inclusive", () => {
  const s = sliceAhead(HRS, "2026-10-25T22", 3)
  assert.equal(s.length, 3)
  assert.equal(s[0].temp, 3)
  assert.equal(s[2].temp, 5)
})
ok("sliceAhead clamps to the tail when nothing is ahead", () => {
  const s = sliceAhead(HRS, "2026-10-27T08", 2)
  assert.deepEqual(s.map(r => r.temp), [4, 5])
})
ok("sliceAhead guards empty input", () => {
  assert.deepEqual(sliceAhead([], "2026-10-25T22", 8), [])
  assert.deepEqual(sliceAhead(null, "2026-10-25T22", 8), [])
})

// ── location parses ────────────────────────────────────────────────────────
ok("ipwho.is parse", () => {
  const l = parseIpwho({ success: true, latitude: 37.98, longitude: 23.73, city: "Athens" })
  assert.equal(l.city, "Athens")
  assert.equal(l.lat, 37.98)
  assert.equal(parseIpwho({ success: false, latitude: 1, longitude: 2 }), null)
  assert.equal(parseIpwho(null), null)
})
ok("geocoding parse", () => {
  const g = parseGeo({ results: [{ name: "Athens", latitude: 37.98, longitude: 23.73 }] })
  assert.equal(g.city, "Athens")
  assert.equal(parseGeo({ results: [] }), null)
  assert.equal(parseGeo({ results: [{ name: "x" }] }), null)
})
ok("guarded JSON", () => {
  assert.equal(parseJson(""), null)
  assert.equal(parseJson("not json"), null)
  assert.deepEqual(parseJson('{"a":1}'), { a: 1 })
})

console.log(`weather.test: ${n} assertions passed`)
