// Usage (from the repo root): node scripts/export_model_history.js > scripts/model_history.csv
// Needs `gcloud auth application-default login` and the functions/ dependencies installed.
const { createRequire } = require("module");
const req = createRequire(require.resolve("../functions/package.json"));
const admin = req("firebase-admin");

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "safeher-app-9251b" });

(async () => {
  const snap = await admin.firestore().collection("model_history").orderBy("at").get();
  const cols = ["at", "candidate", "previous", "cand_roc_auc", "cand_recall", "prev_roc_auc", "prev_recall", "promoted"];
  console.log(cols.join(","));
  for (const d of snap.docs) {
    const x = d.data();
    const c = x.candidate_metrics || {};
    const p = x.previous_metrics || {};
    console.log([x.at ? x.at.toDate().toISOString().slice(0, 10) : "", x.candidate, x.previous || "",
      c.roc_auc ?? "", c.recall_high ?? "", p.roc_auc ?? "", p.recall_high ?? "", x.promoted].join(","));
  }
})().catch((e) => { console.error(e.message); process.exit(1); });
