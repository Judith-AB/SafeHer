"""LAPD incidents with female victims: predict next-month hotspots (~1 km x 6-hour cells).

No public Indian dataset has incident coordinates and times, so this validates the
method at street scale; it says nothing about risk in Kerala.
Usage: python3 ml/real/prepare_la.py data/Crime_Data_from_2020_to_Present.csv
"""
import os
import re
import sys

import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
HOT_SHARE = 0.05
CATEGORY_RULES = [  # first match wins
    ("Sexual offence", r"RAPE|SEXUAL|LEWD|INDECENT EXPOSURE|ORAL COPULATION|SODOMY|PEEPING"),
    ("Stalking", r"STALKING"),
    ("Intimate partner", r"INTIMATE PARTNER"),
    ("Harassment and threats", r"CRIMINAL THREATS|THREATENING|ANNOYING|HARASS"),
    ("Assault", r"ASSAULT|BATTERY"),
]

def parse_hour(df):
    # TIME OCC comes as 2130, "21:30" or "9:30 PM" depending on the export
    col = next((c for c in ("time_occ", "time", "time_of_occurrence") if c in df.columns), None)
    if col is not None:
        raw = df[col].astype(str).str.strip()
        print("sample TIME OCC values:", list(raw.head(5)))
        digits = raw.str.fullmatch(r"\d{1,4}(\.0)?")
        hour = pd.Series(np.nan, index=df.index)
        hhmm = pd.to_numeric(raw[digits].str.replace(".0", "", regex=False), errors="coerce")
        hour[digits] = hhmm // 100
        other = ~digits
        if other.any():
            hour[other] = pd.to_datetime(raw[other], format="mixed", errors="coerce").dt.hour
        if hour.notna().mean() > 0.9 and hour.nunique() > 1:
            return hour.where((hour >= 0) & (hour <= 23))
    d = pd.to_datetime(df["date_occ"], format="mixed", errors="coerce")
    if d.dt.hour.nunique() > 1:
        print("using the time inside DATE OCC")
        return d.dt.hour
    raise SystemExit("Could not read a time of day. Send the first lines of the file: head -3 <file>")

def load(path):
    use = None
    df = pd.read_csv(path, low_memory=False, usecols=use)
    df.columns = [re.sub(r"[^a-z0-9]+", "_", c.strip().lower()).strip("_") for c in df.columns]
    df = df[df["vict_sex"].astype(str).str.upper() == "F"]
    desc = df["crm_cd_desc"].astype(str).str.upper()
    df["category"] = None
    for name, pat in reversed(CATEGORY_RULES):
        df.loc[desc.str.contains(pat, regex=True), "category"] = name
    df = df.dropna(subset=["category"])
    df = df[(df["lat"].abs() > 1) & (df["lon"].abs() > 1)]
    df["date"] = pd.to_datetime(df["date_occ"], format="mixed", errors="coerce")
    df = df.dropna(subset=["date"])
    # LAPD changed records systems in 2024, so later months are incomplete
    df = df[(df["date"] >= "2020-01-01") & (df["date"] < "2024-01-01")]
    df["hour"] = parse_hour(df)
    df = df.dropna(subset=["hour"])
    df["band"] = (df["hour"].astype(int) // 6)   # 0: 00-06, 1: 06-12, 2: 12-18, 3: 18-24
    df["lat_zone"] = df["lat"].round(2)
    df["lng_zone"] = df["lon"].round(2)
    df["month"] = df["date"].dt.to_period("M")
    return df

def build_panel(df):
    months = pd.period_range("2020-01", "2023-12", freq="M")
    counts = df.groupby(["lat_zone", "lng_zone", "band", "month"]).size().rename("n")
    cells = counts.reset_index()[["lat_zone", "lng_zone", "band"]].drop_duplicates()
    idx = pd.MultiIndex.from_frame(cells.merge(pd.DataFrame({"month": months}), how="cross"))
    c = counts.reindex(idx, fill_value=0).unstack("month").sort_index(axis=1)
    arr = c.values.astype(float)

    key = {k: i for i, k in enumerate(c.index)}
    nb = np.zeros_like(arr)
    for (la, lo, b), i in key.items():
        for dla in (-0.01, 0, 0.01):
            for dlo in (-0.01, 0, 0.01):
                if dla == 0 and dlo == 0:
                    continue
                j = key.get((round(la + dla, 2), round(lo + dlo, 2), b))
                if j is not None:
                    nb[i] += arr[j]

    rows = []
    for t in range(12, arr.shape[1] - 1):  # predict month t+1 from months <= t only
        target = arr[:, t + 1]
        cut = np.quantile(target, 1 - HOT_SHARE)
        cut = max(cut, 1)
        rows.append(pd.DataFrame({
            "lat_zone": c.index.get_level_values(0), "lng_zone": c.index.get_level_values(1),
            "band": c.index.get_level_values(2),
            "target_month": str(months[t + 1]),
            "lag1": arr[:, t], "lag3": arr[:, t - 2:t + 1].sum(1), "lag12": arr[:, t - 11:t + 1].sum(1),
            "same_month_last_year": arr[:, t + 1 - 12],
            "nb_lag3": nb[:, t - 2:t + 1].sum(1), "nb_lag12": nb[:, t - 11:t + 1].sum(1),
            "month_of_year": months[t + 1].month,
            "target_count": target,
            "risk_label": np.where(target >= cut, "HIGH", "LOW"),
        }))
    panel = pd.concat(rows, ignore_index=True)
    panel = panel[panel["target_month"] >= "2021-01"]
    panel["split"] = np.where(panel["target_month"] >= "2023-01", "TEST", "TRAIN")
    return panel

def hit_rate_pai(te, score, share=HOT_SHARE):
    # PAI = hit rate / share of area flagged
    hits, tot = 0.0, 0.0
    for _, g in te.assign(s=score).groupby("target_month"):
        k = max(1, int(round(share * len(g))))
        top = g.nlargest(k, "s")
        hits += top["target_count"].sum(); tot += g["target_count"].sum()
    hr = hits / tot if tot else float("nan")
    return hr, hr / share

def evaluate(panel):
    feat = ["band", "lag1", "lag3", "lag12", "same_month_last_year", "nb_lag3", "nb_lag12", "month_of_year"]
    tr, te = panel[panel.split == "TRAIN"], panel[panel.split == "TEST"]
    ytr, yte = (tr.risk_label == "HIGH").astype(int).values, (te.risk_label == "HIGH").astype(int).values
    models = {
        "Last month's count": lambda: te["lag1"].values + 1e-3 * te["lag12"].values,
        "12-month historical count": lambda: te["lag12"].values,
        "Logistic regression": make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000)),
        "Decision tree (depth 4)": DecisionTreeClassifier(max_depth=4, random_state=0),
        "Boosted tree": GradientBoostingClassifier(n_estimators=50, learning_rate=0.1, max_depth=4, random_state=0),
    }
    rows = []
    for name, m in models.items():
        s = m() if callable(m) and not hasattr(m, "fit") else m.fit(tr[feat], ytr).predict_proba(te[feat])[:, 1]
        hr, pai = hit_rate_pai(te, s)
        rows.append({"model": name, "roc_auc": round(roc_auc_score(yte, s), 3),
                     "pr_auc": round(average_precision_score(yte, s), 3),
                     f"hit_rate_top{int(HOT_SHARE*100)}pct": round(hr, 3), "PAI": round(pai, 2)})
    info = (f"cells {panel[['lat_zone','lng_zone','band']].drop_duplicates().shape[0]}, "
            f"train rows {len(tr)}, test rows {len(te)}, HIGH share test {yte.mean():.3f}")
    return pd.DataFrame(rows), info

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "Crime_Data_from_2020_to_Present.csv"
    os.makedirs(OUT, exist_ok=True)
    df = load(path)
    print(f"female-victim incidents kept: {len(df)}")
    print(df["category"].value_counts().to_markdown())
    print(df.groupby("band").size().rename("by 6-hour band").to_markdown())
    if df["band"].nunique() < 4:
        raise SystemExit("Time bands look wrong (fewer than 4). Check the sample TIME OCC values above.")
    panel = build_panel(df)
    res, info = evaluate(panel)
    print(info); print(res.to_markdown(index=False))
    with open(os.path.join(OUT, "la_results.md"), "w") as f:
        f.write(info + "\n\n" + df["category"].value_counts().to_markdown() + "\n\n" + res.to_markdown(index=False))
    res.to_csv(os.path.join(OUT, "la_results.csv"), index=False)

if __name__ == "__main__":
    main()
