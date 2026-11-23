// Usage: node scripts/latency_test.js [url] [requestsPerLevel]
// Run once right after a deploy (cold cache) and once again (warm cache).
const url = process.argv[2] || "https://us-central1-safeher-app-9251b.cloudfunctions.net/getPredictiveHeatmap";
const N = Number(process.argv[3] || 200);
const LEVELS = [1, 10, 50, 100];

const pct = (a, p) => a[Math.min(a.length - 1, Math.floor((p / 100) * a.length))];

async function one() {
  const t = performance.now();
  try {
    const r = await fetch(url);
    await r.arrayBuffer();
    return { ms: performance.now() - t, ok: r.ok };
  } catch {
    return { ms: performance.now() - t, ok: false };
  }
}

async function level(c) {
  const out = [];
  let sent = 0;
  async function worker() {
    while (sent < N) { sent++; out.push(await one()); }
  }
  await Promise.all(Array.from({ length: c }, worker));
  const ms = out.filter((x) => x.ok).map((x) => x.ms).sort((a, b) => a - b);
  const err = out.filter((x) => !x.ok).length;
  return { concurrency: c, requests: out.length, errors: err,
    p50: pct(ms, 50)?.toFixed(0), p95: pct(ms, 95)?.toFixed(0), p99: pct(ms, 99)?.toFixed(0),
    max: ms[ms.length - 1]?.toFixed(0) };
}

(async () => {
  const rows = [];
  for (const c of LEVELS) rows.push(await level(c));
  console.table(rows);
  console.log("| Concurrency | Requests | Errors | p50 ms | p95 ms | p99 ms | max ms |\n| --- | --- | --- | --- | --- | --- | --- |");
  for (const r of rows) console.log(`| ${r.concurrency} | ${r.requests} | ${r.errors} | ${r.p50} | ${r.p95} | ${r.p99} | ${r.max} |`);
})();
