-- After 02 and 03, point the app at the frozen v1 model.
-- Do this from the Firebase console or with the Admin SDK:
--   Firestore doc  model_metrics/current = {
--     model: "safeher-app-9251b.safeher.risk_model_v1",
--     roc_auc: <from 03>, recall: <from 03>, precision: <from 03>,
--     f1_score: <from 03>, accuracy: <from 03>, promoted_at: <now> }
-- weeklyRetrainRiskModel and getPredictiveHeatmap both read this document.
SELECT 1;
