# SafeHer ML: real-data experiments

Two public, real datasets. Neither ships in this repo; download them from Kaggle.

| | Dataset | Unit | Task (label = observed future outcome) | Script |
| --- | --- | --- | --- | --- |
| Main, deployed | NCRB district-wise crimes against women, 2001-2014. Kaggle: `greeshmagirish/crime-against-women-20012014-india` (`Crimes_against_women.csv`) | district x year, all India, Kerala's 14 districts | Will the district be in the national top 20% of recorded crimes against women next year? Train on target years up to 2011, test on 2012-2014. | `real/prepare_ncrb.py` |
| Fine-grained validation | LAPD "Crime Data from 2020 to Present", female victims only. Kaggle mirror or data.lacity.org | ~1 km zone x 6-hour band x month | Will the zone-band be a top-5% hotspot next month? Train 2021-2022, test 2023. | `real/prepare_la.py` |

```
pip install scikit-learn pandas numpy tabulate
python3 ml/real/prepare_ncrb.py data/Crimes_against_women.csv   # ~10 s
python3 ml/real/prepare_la.py data/Crime_Data_from_2020_to_Present.csv   # a few minutes
```

Then load the NCRB outputs into BigQuery and train the deployed model with
`real/sql/ncrb_bqml.sql`.

Baselines that the models must beat: persistence (last year's HIGH status, or last
month's count) and historical counts. On these tasks persistence is usually strong.
Report it straight.

`synthetic_legacy/` only reproduces the submitted paper's synthetic Table 3 for the response letter.
