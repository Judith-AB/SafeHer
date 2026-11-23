// Usage: node scripts/chatbot_eval.js scripts/chatbot_testset.csv
// Needs `npm install` in functions/ and `gcloud auth application-default login`.
const fs = require("fs");
const path = require("path");
const { SessionsClient } = require(path.join(__dirname, "..", "functions", "node_modules", "@google-cloud/dialogflow"));

const PROJECT = process.env.DIALOGFLOW_PROJECT || "safeher-app-9251b";
const INTENT_MAP = {
  fir: "fir.filing",
  domestic_violence: "domestic.violence.rights",
  restraining: "restraining.order",
  pocso: "pocso.act",
  posh: "workplace.harassment",
  cyber: "online.abuse",
  stalking: "stalking.harassment",
  helplines: "legal.helplines",
  out_of_scope: "Default Fallback Intent",
};
const THRESHOLDS = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8];

function readCsv(file) {
  return fs.readFileSync(file, "utf8").trim().split("\n").slice(1).map((line) => {
    const i = line.lastIndexOf(",");
    return { text: line.slice(0, i).replace(/^"|"$/g, ""), label: line.slice(i + 1).trim() };
  });
}

(async () => {
  const rows = readCsv(process.argv[2] || path.join(__dirname, "chatbot_testset.csv"));
  const client = new SessionsClient();
  const results = [];
  for (const [k, r] of rows.entries()) {
    const session = client.projectAgentSessionPath(PROJECT, `eval-${Date.now()}-${k}`);
    const [res] = await client.detectIntent({ session, queryInput: { text: { text: r.text, languageCode: "en" } } });
    const q = res.queryResult;
    results.push({ ...r, expected: INTENT_MAP[r.label], predicted: q.intent?.displayName || "none",
      confidence: q.intentDetectionConfidence || 0, isFallback: Boolean(q.intent?.isFallback) });
  }
  fs.writeFileSync(path.join(__dirname, "chatbot_eval_raw.json"), JSON.stringify(results, null, 1));

  const labels = [...new Set(results.map((r) => r.expected))];
  let correct = 0; const f1s = [];
  console.log("| Intent | n | Precision | Recall | F1 |\n| --- | --- | --- | --- | --- |");
  for (const l of labels) {
    const tp = results.filter((r) => r.expected === l && r.predicted === l).length;
    const fp = results.filter((r) => r.expected !== l && r.predicted === l).length;
    const fn = results.filter((r) => r.expected === l && r.predicted !== l).length;
    const p = tp / (tp + fp || 1), rc = tp / (tp + fn || 1), f = (2 * p * rc) / (p + rc || 1);
    correct += tp; f1s.push(f);
    console.log(`| ${l} | ${tp + fn} | ${p.toFixed(3)} | ${rc.toFixed(3)} | ${f.toFixed(3)} |`);
  }
  console.log(`\nAccuracy ${(correct / results.length).toFixed(3)}, macro-F1 ${(f1s.reduce((a, b) => a + b, 0) / f1s.length).toFixed(3)}, n=${results.length}`);

  // A query "should be referred" if it is out of scope or the intent was misrecognised.
  console.log("\n| Threshold | Referral precision | Referral recall | In-scope answered correctly |\n| --- | --- | --- | --- |");
  for (const t of THRESHOLDS) {
    const refer = (r) => r.isFallback || r.confidence < t;
    const should = (r) => r.label === "out_of_scope" || r.predicted !== r.expected;
    const tp = results.filter((r) => refer(r) && should(r)).length;
    const fp = results.filter((r) => refer(r) && !should(r)).length;
    const fn = results.filter((r) => !refer(r) && should(r)).length;
    const inScope = results.filter((r) => r.label !== "out_of_scope");
    const answered = inScope.filter((r) => !refer(r) && r.predicted === r.expected).length;
    console.log(`| ${t} | ${(tp / (tp + fp || 1)).toFixed(3)} | ${(tp / (tp + fn || 1)).toFixed(3)} | ${(answered / inScope.length).toFixed(3)} |`);
  }

  console.log("\n| Confidence bin | n | Accuracy |\n| --- | --- | --- |");
  for (let b = 0; b < 1; b += 0.2) {
    const bin = results.filter((r) => r.label !== "out_of_scope" && r.confidence >= b && r.confidence < b + 0.2 + (b >= 0.8 ? 0.01 : 0));
    if (bin.length) console.log(`| ${b.toFixed(1)}-${(b + 0.2).toFixed(1)} | ${bin.length} | ${(bin.filter((r) => r.predicted === r.expected).length / bin.length).toFixed(3)} |`);
  }
})();
