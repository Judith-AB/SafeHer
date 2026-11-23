-- Both models on the SAME frozen TRAIN rows. NO_SPLIT stops BigQuery ML from
-- silently holding out another 20% of the training data.
CREATE OR REPLACE MODEL `safeher-app-9251b.safeher.risk_model_v1`
OPTIONS (model_type = 'boosted_tree_classifier', num_parallel_tree = 1, max_tree_depth = 4,
         input_label_cols = ['risk_label'], data_split_method = 'NO_SPLIT') AS
SELECT category, hour_of_day, day_of_week, ROUND(lat, 2) AS lat_zone, ROUND(lng, 2) AS lng_zone,
       IF(risk_score >= 0.6, 'HIGH', 'LOW') AS risk_label
FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` WHERE split = 'TRAIN';

CREATE OR REPLACE MODEL `safeher-app-9251b.safeher.lr_baseline_v1`
OPTIONS (model_type = 'logistic_reg', input_label_cols = ['risk_label'], data_split_method = 'NO_SPLIT') AS
SELECT category, hour_of_day, day_of_week, ROUND(lat, 2) AS lat_zone, ROUND(lng, 2) AS lng_zone,
       IF(risk_score >= 0.6, 'HIGH', 'LOW') AS risk_label
FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` WHERE split = 'TRAIN';

-- Ablation: boosted tree without the zone features
CREATE OR REPLACE MODEL `safeher-app-9251b.safeher.risk_model_nozone_v1`
OPTIONS (model_type = 'boosted_tree_classifier', num_parallel_tree = 1, max_tree_depth = 4,
         input_label_cols = ['risk_label'], data_split_method = 'NO_SPLIT') AS
SELECT category, hour_of_day, day_of_week, IF(risk_score >= 0.6, 'HIGH', 'LOW') AS risk_label
FROM `safeher-app-9251b.safeher.incidents_ml_frozen_v1` WHERE split = 'TRAIN';
