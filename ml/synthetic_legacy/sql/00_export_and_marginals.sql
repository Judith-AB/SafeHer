-- Run FIRST. The original 1,000 synthetic rows are still in BigQuery.
-- 1) Export them so the paper's numbers can be reproduced:
--    bq extract --destination_format CSV \
--      safeher-app-9251b:safeher.incidents_ml gs://<bucket>/incidents_original.csv
--    (or in the console: open the table, Export, CSV)
-- 2) Freeze a copy before live reports touch it again:
CREATE TABLE IF NOT EXISTS `safeher-app-9251b.safeher.incidents_ml_frozen_v1` AS
SELECT * FROM `safeher-app-9251b.safeher.incidents_ml`
WHERE risk_score != 0.5 OR split = 'TRAIN';   -- drops live rows inserted with the 0.5 placeholder

-- 3) Marginals to copy into generate_dataset.py CONFIG and into the paper's dataset section
SELECT split, COUNT(*) n, COUNTIF(risk_score >= 0.6) high, ROUND(COUNTIF(risk_score >= 0.6)/COUNT(*),3) high_share
FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` GROUP BY split;

SELECT category, COUNT(*) n FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` GROUP BY category ORDER BY n DESC;
SELECT hour_of_day, COUNT(*) n FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` GROUP BY 1 ORDER BY 1;
SELECT day_of_week, COUNT(*) n FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` GROUP BY 1 ORDER BY 1;
SELECT MIN(risk_score), MAX(risk_score), AVG(risk_score) FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1`;

-- How many live rows polluted the old TEST split (report this honestly if non-zero)
SELECT COUNT(*) AS live_placeholder_rows FROM `safeher-app-9251b.safeher.incidents_ml`
WHERE risk_score = 0.5 AND split = 'TEST';
