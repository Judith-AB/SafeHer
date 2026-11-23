-- Run once per model: replace risk_model_v1 with lr_baseline_v1 and risk_model_nozone_v1 (drop the zone columns for that one).
-- All three are scored on the SAME TEST rows, which fixes the Table 3 mismatch.

-- Headline metrics at threshold 0.5
SELECT * FROM ML.EVALUATE(MODEL `safeher-app-9251b.safeher.risk_model_v1`,
  (SELECT category, hour_of_day, day_of_week, ROUND(lat,2) lat_zone, ROUND(lng,2) lng_zone,
          IF(risk_score >= 0.6,'HIGH','LOW') risk_label
   FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` WHERE split = 'TEST'));

-- Confusion matrix (paste into the paper)
SELECT * FROM ML.CONFUSION_MATRIX(MODEL `safeher-app-9251b.safeher.risk_model_v1`,
  (SELECT category, hour_of_day, day_of_week, ROUND(lat,2) lat_zone, ROUND(lng,2) lng_zone,
          IF(risk_score >= 0.6,'HIGH','LOW') risk_label
   FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` WHERE split = 'TEST'));

-- ROC points for Fig. 2 (export and plot both models on one chart)
SELECT * FROM ML.ROC_CURVE(MODEL `safeher-app-9251b.safeher.risk_model_v1`,
  (SELECT category, hour_of_day, day_of_week, ROUND(lat,2) lat_zone, ROUND(lng,2) lng_zone,
          IF(risk_score >= 0.6,'HIGH','LOW') risk_label
   FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` WHERE split = 'TEST'));

-- Confirm the training row count (should equal the TRAIN count, not 80% of it)
SELECT * FROM ML.TRAINING_INFO(MODEL `safeher-app-9251b.safeher.risk_model_v1`);
