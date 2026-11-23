# SafeHer ML reproducibility package

Everything needed to regenerate Table 3 and the new baseline, ablation and
sensitivity tables.

| Step | Command | Output |
| --- | --- | --- |
| 1 | Run `sql/00_export_and_marginals.sql`, export the table to `data/incidents_original.csv` | frozen copy of the original data plus its marginals |
| 2 | Edit the CONFIG block in `generate_dataset.py` to match those marginals | generator that matches the paper's data |
| 3 | `python3 evaluate.py --csv data/incidents_original.csv` | confusion matrices, bootstrap CIs, McNemar test, ROC figure for the paper's own data |
| 4 | `python3 evaluate.py --seeds 30` | baselines, ablation and threshold sensitivity over 30 regenerated datasets |
| 5 | `sql/01` to `sql/04` in BigQuery | BigQuery ML headline numbers on one frozen split |

Requirements: Python 3.10+, `pip install scikit-learn pandas numpy matplotlib tabulate`.
A full 30-seed run takes about one minute on a laptop.

The scikit-learn boosted tree mirrors BigQuery ML defaults (20 iterations,
learning rate 0.3, depth 4) but is not identical. Report BigQuery ML for the
headline row and say the intervals come from the scikit-learn replication.
