"""NCRB district panel: predict which districts rank in India's top 20% next year.

Usage: python3 ml/real/prepare_ncrb.py data/Crimes_against_women.csv [--top-share=0.2]
Upload ncrb_panel.csv and kerala_forecast.csv to BigQuery only from the default 0.2 run.
"""
import os
import re
import sys

import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, f1_score, precision_score, recall_score, roc_auc_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
TOP_SHARE = 0.20
LAGS = 3
TEST_YEARS = (2012, 2013, 2014)
EXCLUDE = re.compile(r"TOTAL|RLY|RAILWAY|G\.?R\.?P|C\.?I\.?D|CRIME BRANCH|STF|SPL|CBCID|COMMR\.? *OF POLICE \(HQ\)", re.I)

# approximate district HQ coordinates, used for the app map
KERALA = {
    "THIRUVANANTHAPURAM": (8.524, 76.937), "KOLLAM": (8.893, 76.614), "PATHANAMTHITTA": (9.265, 76.787),
    "ALAPPUZHA": (9.498, 76.339), "KOTTAYAM": (9.592, 76.522), "IDUKKI": (9.850, 76.972),
    "ERNAKULAM": (9.982, 76.300), "THRISSUR": (10.528, 76.214), "PALAKKAD": (10.787, 76.655),
    "MALAPPURAM": (11.051, 76.071), "KOZHIKODE": (11.259, 75.780), "WAYANAD": (11.685, 76.132),
    "KANNUR": (11.874, 75.370), "KASARAGOD": (12.500, 74.990),
}
KERALA_ALIASES = {"TRIVANDRUM": "THIRUVANANTHAPURAM", "QUILON": "KOLLAM", "ALLEPPEY": "ALAPPUZHA",
                  "KOCHI": "ERNAKULAM", "COCHIN": "ERNAKULAM", "TRICHUR": "THRISSUR", "PALGHAT": "PALAKKAD",
                  "CALICUT": "KOZHIKODE", "CANNANORE": "KANNUR", "KASARGOD": "KASARAGOD", "KASARAGODE": "KASARAGOD",
                  "KASARGODE": "KASARAGOD", "KASAR": "KASARAGOD", "WYNAD": "WAYANAD", "WAYNAD": "WAYANAD",
                  "PATANAMTHITTA": "PATHANAMTHITTA", "PATHANAMTITTA": "PATHANAMTHITTA", "PTA": "PATHANAMTHITTA",
                  "MALAPURAM": "MALAPPURAM", "ALAPUZHA": "ALAPPUZHA", "ALLAPPUZHA": "ALAPPUZHA",
                  "ERANAKULAM": "ERNAKULAM", "IDUKKKI": "IDUKKI", "THRISSUR": "THRISSUR", "PALGHAT": "PALAKKAD"}

def kerala_district(name):
    n = name.upper()
    for alias, canon in KERALA_ALIASES.items():
        if alias in n:
            return canon
    for canon in KERALA:
        if canon in n:
            return canon
    return None

def load(path):
    df = pd.read_csv(path)
    df.columns = [re.sub(r"[^a-z0-9]+", "_", c.strip().lower()).strip("_") for c in df.columns]
    # index columns such as "Unnamed: 0" are not crime counts
    df = df.loc[:, [c for c in df.columns if not c.startswith(("unnamed", "index", "id", "sl_no", "s_no"))]]
    crime_cols = [c for c in df.columns if c not in ("state", "state_ut", "district", "year")]
    print("crime columns used:", ", ".join(crime_cols))
    state_col = "state" if "state" in df.columns else "state_ut"
    df = df.rename(columns={state_col: "state"})
    df["state"] = df["state"].str.strip().str.upper().str.replace("&", "AND")
    df["district"] = df["district"].astype(str).str.strip().str.upper()
    df = df[~df["district"].str.contains(EXCLUDE)]
    # Kerala reports city and rural police districts separately
    is_k = df["state"].str.contains("KERALA")
    df.loc[is_k, "district"] = df.loc[is_k, "district"].map(kerala_district)
    df = df.dropna(subset=["district"])
    df[crime_cols] = df[crime_cols].apply(pd.to_numeric, errors="coerce").fillna(0)
    df = df.groupby(["state", "district", "year"], as_index=False)[crime_cols].sum()
    df["total"] = df[crime_cols].sum(axis=1)
    return df, crime_cols

def build_panel(df, crime_cols):
    # Recorded counts jump between years (definitions and reporting changed), so
    # features are within-year percentiles and category shares, not raw counts.
    df = df.sort_values(["state", "district", "year"]).copy()
    df["pct"] = df.groupby("year")["total"].rank(pct=True)
    for c in crime_cols:
        df[f"{c}_share"] = df[c] / df["total"].where(df["total"] > 0, 1)
    g = df.groupby(["state", "district"])
    feats = {}
    for k in range(1, LAGS + 1):
        feats[f"pct_lag{k}"] = g["pct"].shift(k)
    feats["total_lag1"] = g["total"].shift(1)   # baseline only
    feats["total_lag2"] = g["total"].shift(2)
    for c in crime_cols:
        feats[f"{c}_share_lag1"] = g[f"{c}_share"].shift(1)
    panel = pd.concat([df[["state", "district", "year", "total"]], pd.DataFrame(feats)], axis=1)
    panel["pct_change_lag1"] = panel["pct_lag1"] - panel["pct_lag2"]
    panel["prev_year"] = g["year"].shift(LAGS)
    panel = panel[panel["year"] - panel["prev_year"] == LAGS].drop(columns="prev_year")
    # the label is an observed outcome in the target year, never computed from the features
    cut = panel.groupby("year")["total"].transform(lambda s: s.quantile(1 - TOP_SHARE))
    panel["risk_label"] = np.where(panel["total"] >= cut, "HIGH", "LOW")
    yr_cut = df.groupby("year")["total"].quantile(1 - TOP_SHARE)
    panel["was_high_lag1"] = (panel["total_lag1"] >= panel["year"].sub(1).map(yr_cut)).astype(int)
    panel["is_kerala"] = panel["state"].str.contains("KERALA").astype(int)
    panel["split"] = np.where(panel["year"].isin(TEST_YEARS), "TEST", "TRAIN")
    return panel.drop(columns=["total", "total_lag2"]).fillna(0)

def metrics(y, score, pred):
    one = len(set(y)) < 2
    tn = int(((pred == 0) & (y == 0)).sum()); fp = int(((pred == 1) & (y == 0)).sum())
    return {"precision": precision_score(y, pred, zero_division=0), "recall": recall_score(y, pred, zero_division=0),
            "specificity": tn / (tn + fp) if tn + fp else float("nan"), "f1": f1_score(y, pred, zero_division=0),
            "roc_auc": float("nan") if one else roc_auc_score(y, score),
            "pr_auc": float("nan") if one else average_precision_score(y, score)}

def top_per_year(te, s):
    # same rule that defines the label, so precision and recall compare fairly
    out = np.zeros(len(te), dtype=int)
    for y in te.year.unique():
        idx = np.where(te.year.values == y)[0]
        k = int(round(TOP_SHARE * len(idx)))
        out[idx[np.argsort(-s[idx])[:k]]] = 1
    return out

def evaluate(panel):
    feat = [c for c in panel.columns if c.startswith("pct_") or c.endswith("_share_lag1") or c == "was_high_lag1"]
    tr, te = panel[panel.split == "TRAIN"], panel[panel.split == "TEST"]
    ytr, yte = (tr.risk_label == "HIGH").astype(int).values, (te.risk_label == "HIGH").astype(int).values
    models = {
        "Persistence (HIGH last year)": None,
        "Last year's rank (top 20% flagged)": None,
        "Logistic regression": make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000)),
        "Decision tree (depth 4)": DecisionTreeClassifier(max_depth=4, random_state=0),
        "Random forest": RandomForestClassifier(n_estimators=300, max_depth=8, random_state=0),
        "Boosted tree": GradientBoostingClassifier(n_estimators=20, learning_rate=0.3, max_depth=4, random_state=0),
    }
    rows, rng = [], np.random.default_rng(0)
    for name, m in models.items():
        if name.startswith("Persistence"):
            s = te.was_high_lag1.values.astype(float); p = s.astype(int)
        elif name.startswith("Last year"):
            s = te.pct_lag1.values.astype(float)
            p = top_per_year(te, s)
        else:
            m.fit(tr[feat], ytr); s = m.predict_proba(te[feat])[:, 1]; p = top_per_year(te, s)
        point = metrics(yte, s, p)
        boots = [metrics(yte[i], s[i], p[i]) for i in (rng.integers(0, len(yte), len(yte)) for _ in range(1000))]
        row = {"model": name}
        for k, v in point.items():
            lo, hi = np.nanpercentile([b[k] for b in boots], [2.5, 97.5])
            row[k] = f"{v:.3f} [{lo:.3f}, {hi:.3f}]"
        k_mask = te.is_kerala.values == 1
        row["kerala_roc_auc"] = f"{roc_auc_score(yte[k_mask], s[k_mask]):.3f}" if k_mask.sum() and len(set(yte[k_mask])) > 1 else "n/a"
        rows.append(row)
    res = pd.DataFrame(rows)
    feat_note = ", ".join(feat)
    info = (f"features: {feat_note}\ntrain rows {len(tr)} (target years {tr.year.min()}-{tr.year.max()}), "
            f"test rows {len(te)} ({te.year.min()}-{te.year.max()}), HIGH share test {yte.mean():.3f}, "
            f"Kerala test rows {int(te.is_kerala.sum())}")
    return res, info, feat

def kerala_forecast(df, crime_cols):
    last = df.year.max()
    df = df.copy()
    df["pct"] = df.groupby("year")["total"].rank(pct=True)
    yr_cut = df[df.year == last]["total"].quantile(1 - TOP_SHARE)
    k = df[df.state.str.contains("KERALA")]
    rows, missing = [], []
    for d in KERALA:
        sub = k[k.district == d].set_index("year")
        if not all(y in sub.index for y in range(last - LAGS + 1, last + 1)):
            missing.append(d); continue
        r = {"state": "KERALA", "district": d, "year": last + 1}
        for j in range(1, LAGS + 1):
            r[f"pct_lag{j}"] = sub.loc[last - j + 1, "pct"]
        r["total_lag1"] = sub.loc[last, "total"]
        tot = sub.loc[last, "total"] or 1
        for c in crime_cols:
            r[f"{c}_share_lag1"] = sub.loc[last, c] / tot
        r["pct_change_lag1"] = r["pct_lag1"] - r["pct_lag2"]
        r["was_high_lag1"] = int(sub.loc[last, "total"] >= yr_cut)
        r["lat"], r["lng"] = KERALA[d]
        rows.append(r)
    if missing:
        names = sorted(df[df.state.str.contains("KERALA")].district.unique())
        print(f"WARNING: no forecast for {missing}. Kerala names after mapping: {names}")
    return pd.DataFrame(rows)

def main():
    global TOP_SHARE
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for a in sys.argv[1:]:
        if a.startswith("--top-share="):
            TOP_SHARE = float(a.split("=")[1])
    path = args[0] if args else "Crimes_against_women.csv"
    os.makedirs(OUT, exist_ok=True)
    df, crime_cols = load(path)
    panel = build_panel(df, crime_cols)
    print(f"label: top {TOP_SHARE:.0%} of districts nationally next year")
    panel.to_csv(os.path.join(OUT, "ncrb_panel.csv"), index=False)
    res, info, _ = evaluate(panel)
    print(info)
    print(res.to_markdown(index=False))
    res.to_csv(os.path.join(OUT, "ncrb_results.csv"), index=False)
    with open(os.path.join(OUT, "ncrb_results.md"), "w") as f:
        f.write(info + "\n\n" + res.to_markdown(index=False))
    kf = kerala_forecast(df, crime_cols)
    kf.to_csv(os.path.join(OUT, "kerala_forecast.csv"), index=False)
    print(f"\nKerala districts with a forecast row: {len(kf)} -> out/kerala_forecast.csv")
    print(f"States {df.state.nunique()}, districts {df.groupby('state').district.nunique().sum()}, years {df.year.min()}-{df.year.max()}")

if __name__ == "__main__":
    main()
