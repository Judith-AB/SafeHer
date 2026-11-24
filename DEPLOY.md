# Camera-ready deployment checklist (run in this order)

## 0. Moving to a new Google account and project (do this first if the old project is lost)

If anyone still has Owner on the old project, add the new email there instead
(IAM & Admin > IAM > Grant access > Owner) and skip this section.

1. With the new email, create a Firebase project (console.firebase.google.com). Note its project ID.
2. `bash scripts/switch_project.sh NEW_PROJECT_ID`  (rewrites every hardcoded ID in the repo)
3. `bash scripts/setup_new_project.sh NEW_PROJECT_ID`  (APIs, Firestore in asia-south1, BigQuery dataset, IAM)
4. Firebase console: Blaze plan with a budget alert, and enable Anonymous sign-in.
5. `cd functions && npm install && cd .. && node dialogflow/create_agent.js NEW_PROJECT_ID`
   rebuilds the 7-intent agent from `dialogflow/intents.json`. Person 3 checks every answer there first.
6. `cd app && flutterfire configure --project=NEW_PROJECT_ID`
7. Continue with step 1 below. Steps 4 and 9 (old documents, old key) no longer apply.

What does not carry over: old Firestore reports, old BigQuery tables and models, the old Dialogflow agent,
and the old metrics. None of these are needed for the camera-ready: the model is retrained on NCRB data
and the chatbot is re-evaluated on the rebuilt agent.

Owner: Person 2. Every step takes minutes. Tick each one and paste the output into the team channel.

1. **Real data** (Person 1): download the two Kaggle datasets, run `ml/real/prepare_ncrb.py`
   (and `prepare_la.py`), then load `ncrb_panel.csv` and `kerala_forecast.csv` into BigQuery (commands at the top of `ml/real/sql/ncrb_bqml.sql`).
2. **Train and evaluate** the NCRB models: rest of `ml/real/sql/ncrb_bqml.sql`. Also run `ml/synthetic_legacy/sql/01_tables.sql` once, for the `incidents_live` table.
3. **Create the model pointer** `model_metrics/current = { model: "safeher-app-9251b.safeher.ncrb_risk_model_v1", roc_auc, recall, precision, f1_score, accuracy }`.
4. **Remove stale documents** written by the old app:
   delete `analytics/summary` (new schema), `heatmap_cache/*`, and the `sos_log` collection.
   Old `incidents` documents still hold `anonymous_uid`: run this once from Cloud Shell:
   ```
   node -e "const a=require('firebase-admin');a.initializeApp();const d=a.firestore();
   d.collection('incidents').get().then(s=>Promise.all(s.docs.map(x=>x.ref.update({anonymous_uid:a.firestore.FieldValue.delete()}))))
   .then(()=>console.log('done'))"
   ```
5. **IAM**: give the Cloud Functions runtime service account the `Dialogflow API Client` role (done by `setup_new_project.sh` on a new project).
6. **Dialogflow console**: Settings > General > turn OFF "Log interactions to Cloud Logging" (stops chat text being logged).
7. **Deploy**:
   ```
   cd functions && npm install && npm test && cd ..
   firebase deploy --only firestore:rules,functions
   # answer yes when asked to delete weeklyRetrainRiskModel; it is replaced by scheduledRetrainRiskModel
   ```
8. **TTL policies** (Firestore deletes documents after `expireAt`):
   ```
   for c in incidents sos_events unresolved_legal_queries; do
     gcloud firestore fields ttls update expireAt --collection-group=$c --enable-ttl --project=safeher-app-9251b
   done
   ```
9. **Rotate the old Dialogflow key** if any APK was ever built with a real `dialog_flow_auth.json`:
   IAM > Service accounts > Keys > delete it. The app no longer needs it.
10. **App**: `cd app && flutterfire configure && flutter pub get && flutter analyze && flutter test && flutter run`.
    Then check: submit a report, open the heatmap, ask the bot an in-scope and an out-of-scope question, long-press SOS.
11. **Rules tests** (needs Java): `cd rules-test && npm install && npm test`.

## Rolling back the risk model
Option A (console, no setup): Firestore > `model_metrics/current` > set `model` to a kept version
(for example `safeher-app-9251b.safeher.ncrb_risk_model_v1`) and copy its metrics from `model_history`,
then delete `heatmap_cache/current`.
Option B (function): `cd functions && node ../scripts/set_admin.js YOUR_UID` once, then call
`rollbackRiskModel({ model: "ncrb_risk_model_v1" })` from a signed-in admin client. It re-evaluates the
model, updates the pointer, clears the cache and logs the rollback in `model_history`.

## Privacy clean-up after deploying these rules
Firestore console > `analytics/summary` > delete the `by_area` field (old per-locality counts).
