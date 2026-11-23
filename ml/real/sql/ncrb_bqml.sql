-- Load the outputs of prepare_ncrb.py first:
--   bq load --autodetect --replace --source_format=CSV safeher.ncrb_panel ml/real/out/ncrb_panel.csv
--   bq load --autodetect --replace --source_format=CSV safeher.kerala_forecast ml/real/out/kerala_forecast.csv
-- String labels make BigQuery ML treat LOW as the positive class: use AUC from ML.EVALUATE,
-- and compute HIGH-class precision and recall from ML.PREDICT.

CREATE OR REPLACE MODEL `safeher-app-9251b.safeher.ncrb_risk_model_v1`
OPTIONS (model_type = 'boosted_tree_classifier', num_parallel_tree = 1, max_tree_depth = 4,
         input_label_cols = ['risk_label'], data_split_method = 'NO_SPLIT') AS
SELECT * EXCEPT (state, district, year, split, is_kerala, total_lag1)
FROM `safeher-app-9251b.safeher.ncrb_panel` WHERE split = 'TRAIN';

CREATE OR REPLACE MODEL `safeher-app-9251b.safeher.ncrb_lr_v1`
OPTIONS (model_type = 'logistic_reg', input_label_cols = ['risk_label'], data_split_method = 'NO_SPLIT') AS
SELECT * EXCEPT (state, district, year, split, is_kerala, total_lag1)
FROM `safeher-app-9251b.safeher.ncrb_panel` WHERE split = 'TRAIN';

SELECT * FROM ML.EVALUATE(MODEL `safeher-app-9251b.safeher.ncrb_risk_model_v1`,
  (SELECT * EXCEPT (state, district, year, split, is_kerala, total_lag1)
   FROM `safeher-app-9251b.safeher.ncrb_panel` WHERE split = 'TEST'));
SELECT * FROM ML.CONFUSION_MATRIX(MODEL `safeher-app-9251b.safeher.ncrb_risk_model_v1`,
  (SELECT * EXCEPT (state, district, year, split, is_kerala, total_lag1)
   FROM `safeher-app-9251b.safeher.ncrb_panel` WHERE split = 'TEST'));
SELECT * FROM ML.ROC_CURVE(MODEL `safeher-app-9251b.safeher.ncrb_risk_model_v1`,
  (SELECT * EXCEPT (state, district, year, split, is_kerala, total_lag1)
   FROM `safeher-app-9251b.safeher.ncrb_panel` WHERE split = 'TEST'));

-- Kerala only
SELECT * FROM ML.EVALUATE(MODEL `safeher-app-9251b.safeher.ncrb_risk_model_v1`,
  (SELECT * EXCEPT (state, district, year, split, is_kerala, total_lag1)
   FROM `safeher-app-9251b.safeher.ncrb_panel` WHERE split = 'TEST' AND is_kerala = 1));

SELECT * FROM ML.FEATURE_IMPORTANCE(MODEL `safeher-app-9251b.safeher.ncrb_risk_model_v1`);

-- next-year Kerala forecast shown in the app
SELECT district, year, predicted_risk_label,
       (SELECT p.prob FROM UNNEST(predicted_risk_label_probs) p WHERE p.label = 'HIGH') AS p_high
FROM ML.PREDICT(MODEL `safeher-app-9251b.safeher.ncrb_risk_model_v1`,
  (SELECT * FROM `safeher-app-9251b.safeher.kerala_forecast`))
ORDER BY p_high DESC;
