// =============================================================================
// shared/calendar.mjs — month-grid math (DU6: the ONE calendar grid module)
// =============================================================================
// Consumers (synced copies — separate -c roots cannot import across):
//   • settings/components/CalendarWidget.qml   (Dashboard hero calendar)
//   • plugins/nikos.clock/CalendarPanel.qml    (clock plugin's today card)
//
// MON-start doctrine: both UIs lay a fixed 42-cell (6-row) grid where column
// 0 is Monday, so the weekend is always cells ≡5,6 (mod 7).
// =============================================================================

// Fixed 6-row grid — every month renders the same height.
export const CELL_COUNT = 42

// Grid cells before day 1 (0 = the month starts on Monday).
export function startOffset(year, month) {
    return (new Date(year, month, 1).getDay() + 6) % 7
}

// Days in month (month 0-based; day 0 of the next month = last of this one).
export function daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate()
}

// Month navigation with year wrap. Returns {year, month} — QML callers
// reassign both properties from the result (a var property pair can't be
// mutated in place without losing change signals).
export function shiftMonth(year, month, delta) {
    var m = month + delta
    var y = year
    if (m < 0)       { m = 11; y -= 1 }
    else if (m > 11) { m = 0;  y += 1 }
    return { year: y, month: m }
}
