// b64.test.mjs — b64encode against node's own encoder (the oracle).
import { b64encode } from "./b64.mjs";

let fails = 0;
function ok(cond, name) { console.log((cond ? "  ok " : "  FAIL ") + name); if (!cond) fails++; }
function oracle(s) { return Buffer.from(s, "latin1").toString("base64"); }

const CASES = [
    "", "a", "ab", "abc", "abcd",           // padding boundaries
    "<svg width=\"24\"></svg>",              // the real payload shape (ArchLogo)
    "M15.7733 10.2843L23.998 2.05957",      // digits+dots+spaces
    "fill=\"#e0e0e0\"/>",                    // # and quotes
    "\xE9\xFF\x01",                          // high Latin-1 bytes
];
for (const s of CASES) ok(b64encode(s) === oracle(s), JSON.stringify(s.slice(0, 24)) + " matches oracle");
ok(b64encode("ab") === "YWI=", "known vector ab");
ok(b64encode("abc") === "YWJj", "known vector abc");

console.log(fails === 0 ? "b64.test: OK" : "b64.test: FAIL");
process.exitCode = fails === 0 ? 0 : 1;
