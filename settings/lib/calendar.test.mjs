// calendar.test.mjs — month-grid math for shared/calendar.mjs (DU6).
// Run: tools/run-unit-tests (auto-discovered). Plain asserts, no framework.
import { CELL_COUNT, startOffset, daysInMonth, shiftMonth } from "./calendar.mjs";

let failed = 0;
function ok(cond, name) {
    if (cond) { console.log("  ok", name); }
    else { console.error("  FAIL", name); failed++; }
}

ok(CELL_COUNT === 42, "fixed 42-cell grid");

// Oct 1 2026 is a Thursday → getDay()=4 → MON-start offset 3.
ok(startOffset(2026, 9) === 3, "Oct 2026 starts Thursday → offset 3");
// Sep 1 2025 was a Monday → offset 0.
ok(startOffset(2025, 8) === 0, "Monday start → offset 0");
// Mar 1 2026 is a Sunday → getDay()=0 → offset 6.
ok(startOffset(2026, 2) === 6, "Sunday start → offset 6");

ok(daysInMonth(2026, 9) === 31, "October has 31");
ok(daysInMonth(2024, 1) === 29, "Feb 2024 leap → 29");
ok(daysInMonth(2023, 1) === 28, "Feb 2023 → 28");
ok(daysInMonth(2026, 11) === 31, "December has 31");
ok(daysInMonth(2026, 3) === 30, "April has 30");

var r = shiftMonth(2026, 9, 1);
ok(r.year === 2026 && r.month === 10, "next month plain");
r = shiftMonth(2026, 11, 1);
ok(r.year === 2027 && r.month === 0, "Dec +1 wraps into next year");
r = shiftMonth(2026, 0, -1);
ok(r.year === 2025 && r.month === 11, "Jan −1 wraps into prior year");
r = shiftMonth(2026, 9, -1);
ok(r.year === 2026 && r.month === 8, "prev month plain");
r = shiftMonth(2026, 9, 0);
ok(r.year === 2026 && r.month === 9, "delta 0 is identity");

process.exit(failed ? 1 : 0);
