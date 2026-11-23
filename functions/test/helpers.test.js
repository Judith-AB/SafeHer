const { test } = require("node:test");
const assert = require("node:assert");
const { roundCoord, istParts, truncateToIstHour, hourBand, inIndia } = require("../lib/helpers");

test("rounds to 3 decimals (~111 m)", () => {
  assert.strictEqual(roundCoord(9.931234), 9.931);
  assert.strictEqual(roundCoord(76.2675), 76.268);
});
test("hour and weekday use IST, not UTC", () => {
  // 2026-11-21 18:45 UTC = 2026-11-22 00:15 IST (a Sunday)
  const p = istParts(new Date("2026-11-21T18:45:00Z"));
  assert.deepStrictEqual(p, { hour: 0, day: 0 });
});
test("truncates to the IST hour", () => {
  const t = truncateToIstHour(new Date("2026-11-21T18:45:00Z"));
  assert.strictEqual(t.toISOString(), "2026-11-21T18:30:00.000Z"); // 00:00 IST
});
test("hour bands", () => {
  assert.strictEqual(hourBand(3), "00-06");
  assert.strictEqual(hourBand(23), "18-24");
});
test("India bounding box", () => {
  assert.ok(inIndia(9.93, 76.27));
  assert.ok(!inIndia(51.5, -0.12));
  assert.ok(!inIndia(NaN, 76));
});
