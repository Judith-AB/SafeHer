-- Schema of the labelled (synthetic) training table
CREATE TABLE IF NOT EXISTS `safeher-app-9251b.safeher.incidents_ml` (
  lat FLOAT64, lng FLOAT64, category STRING,
  hour_of_day INT64, day_of_week INT64,   -- day_of_week: 0 = Sunday (JavaScript getDay)
  risk_score FLOAT64, split STRING        -- 'TRAIN' or 'TEST'
);

-- NEW: live reports go here, never into the labelled table.
-- They carry no risk score because a real report has no ground-truth label.
CREATE TABLE IF NOT EXISTS `safeher-app-9251b.safeher.incidents_live` (
  incident_id STRING, lat FLOAT64, lng FLOAT64, category STRING,
  hour_of_day INT64, day_of_week INT64, reported_hour TIMESTAMP
)
PARTITION BY DATE(reported_hour)
OPTIONS (partition_expiration_days = 365);
