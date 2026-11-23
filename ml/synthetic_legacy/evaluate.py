"""Baselines, ablations, repeated runs and threshold sensitivity for SafeHer. Kept only to reproduce the submitted paper's synthetic results."""
import argparse
import math
import os

import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, average_precision_score, f1_score,
                             precision_score, recall_score, roc_auc_score, roc_curve)
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

import generate_dataset as gen

CATS = list(gen.CATEGORY_W)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")

def features(df, use=("cat", "time", "zone")):
    cols = []
    if "cat" in use:
        for c in CATS:
            cols.append((df["category"] == c).astype(float).rename(f"cat_{c}"))
    if "time" in use:
        cols += [df["hour_of_day"].astype(float), df["day_of_week"].astype(float)]
    if "zone" in use:
        cols += [df["lat"].round(2).rename("lat_zone"), df["lng"].round(2).rename("lng_zone")]
    return pd.concat(cols, axis=1).to_numpy()

def labels(df, threshold=None):
    if threshold is None:
        return (df["risk_label"] == "HIGH").astype(int).to_numpy()
    return (df["risk_score"] >= threshold).astype(int).to_numpy()

def rule_score(df):
    return np.array([gen.clean_score(c, h, d) if c in gen.CATEGORY_W else 0.0
                     for c, h, d in zip(df["category"], df["hour_of_day"], df["day_of_week"])])

def boosted(seed):
    return GradientBoostingClassifier(n_estimators=20, learning_rate=0.3, max_depth=4, random_state=seed)

MODELS = {
    "Always HIGH": None,
    "Rule oracle (noise-free Table 2)": None,
    "Category only (tree)": lambda s: (DecisionTreeClassifier(random_state=s), ("cat",)),
    "Logistic regression": lambda s: (make_pipeline(StandardScaler(), LogisticRegression(max_iter=1000)), ("cat", "time", "zone")),
    "Decision tree (depth 4)": lambda s: (DecisionTreeClassifier(max_depth=4, random_state=s), ("cat", "time", "zone")),
    "Random forest": lambda s: (RandomForestClassifier(n_estimators=200, max_depth=6, random_state=s), ("cat", "time", "zone")),
    "Boosted tree": lambda s: (boosted(s), ("cat", "time", "zone")),
}
ABLATIONS = {
    "Boosted tree, all features": ("cat", "time", "zone"),
    "  without zone": ("cat", "time"),
    "  without time": ("cat", "zone"),
    "  without category": ("time", "zone"),
    "  zone only": ("zone",),
}

def metrics(y, pred, score):
    tp = int(((pred == 1) & (y == 1)).sum()); tn = int(((pred == 0) & (y == 0)).sum())
    fp = int(((pred == 1) & (y == 0)).sum()); fn = int(((pred == 0) & (y == 1)).sum())
    one_class = len(set(y)) < 2
    return {
        "accuracy": accuracy_score(y, pred),
        "precision": precision_score(y, pred, zero_division=0),
        "recall": recall_score(y, pred, zero_division=0),
        "specificity": tn / (tn + fp) if tn + fp else float("nan"),
        "f1": f1_score(y, pred, zero_division=0),
        "roc_auc": float("nan") if one_class else roc_auc_score(y, score),
        "pr_auc": float("nan") if one_class else average_precision_score(y, score),
        "TP": tp, "FP": fp, "FN": fn, "TN": tn,
    }

def run_models(df, seed, threshold=None):
    tr, te = df[df["split"] == "TRAIN"], df[df["split"] == "TEST"]
    ytr, yte = labels(tr, threshold), labels(te, threshold)
    out, preds = {}, {}
    for name, factory in MODELS.items():
        if name == "Always HIGH":
            p = np.ones_like(yte); s = np.ones(len(yte))
        elif name.startswith("Rule oracle"):
            s = rule_score(te); p = (s >= (threshold or gen.THRESHOLD)).astype(int)
        else:
            model, use = factory(seed)
            model.fit(features(tr, use), ytr)
            s = model.predict_proba(features(te, use))[:, 1]; p = (s >= 0.5).astype(int)
        out[name] = metrics(yte, p, s); preds[name] = (p, s)
    return out, preds, yte

def run_ablations(df, seed):
    tr, te = df[df["split"] == "TRAIN"], df[df["split"] == "TEST"]
    ytr, yte = labels(tr), labels(te)
    out = {}
    for name, use in ABLATIONS.items():
        m = boosted(seed).fit(features(tr, use), ytr)
        s = m.predict_proba(features(te, use))[:, 1]
        out[name] = metrics(yte, (s >= 0.5).astype(int), s)
    return out

SHOW = ["accuracy", "precision", "recall", "specificity", "f1", "roc_auc", "pr_auc"]

def summarise(runs):
    """runs: list of {model: metrics}. Returns mean and 2.5/97.5 percentiles."""
    rows = []
    for name in runs[0]:
        row = {"model": name}
        for k in SHOW:
            v = np.array([r[name][k] for r in runs], dtype=float)
            v = v[~np.isnan(v)]
            if len(v) == 0:
                row[k] = "n/a"; continue
            lo, hi = np.percentile(v, [2.5, 97.5])
            row[k] = f"{v.mean():.3f} [{lo:.3f}, {hi:.3f}]" if len(runs) > 1 else f"{v.mean():.3f}"
        rows.append(row)
    return pd.DataFrame(rows)

def bootstrap(yte, preds, n=1000, seed=0):
    rng = np.random.default_rng(seed)
    runs = []
    for _ in range(n):
        idx = rng.integers(0, len(yte), len(yte))
        runs.append({name: metrics(yte[idx], p[idx], s[idx]) for name, (p, s) in preds.items()})
    return summarise(runs)

def mcnemar(y, pa, pb):
    b = int(((pa == y) & (pb != y)).sum()); c = int(((pa != y) & (pb == y)).sum())
    if b + c == 0:
        return b, c, 1.0
    chi2 = (abs(b - c) - 1) ** 2 / (b + c)
    p = math.erfc(math.sqrt(chi2 / 2))  # chi-square with 1 dof
    return b, c, p

def save(df, name):
    os.makedirs(OUT, exist_ok=True)
    df.to_csv(os.path.join(OUT, name + ".csv"), index=False)
    with open(os.path.join(OUT, name + ".md"), "w") as f:
        f.write(df.to_markdown(index=False))
    print(f"\n== {name}\n" + df.to_markdown(index=False))

def roc_figure(yte, preds, path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(4.2, 4.2))
    for name in ["Boosted tree", "Logistic regression", "Decision tree (depth 4)", "Rule oracle (noise-free Table 2)"]:
        fpr, tpr, _ = roc_curve(yte, preds[name][1])
        ax.plot(fpr, tpr, label=f"{name} (AUC {roc_auc_score(yte, preds[name][1]):.3f})", lw=1.4)
    ax.plot([0, 1], [0, 1], "k:", lw=0.8, label="Chance")
    ax.set_xlabel("False positive rate"); ax.set_ylabel("True positive rate")
    ax.legend(fontsize=6.5, loc="lower right"); ax.set_aspect("equal")
    fig.tight_layout(); fig.savefig(path); fig.savefig(path.replace(".pdf", ".png"), dpi=200)
    print("wrote", path)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=30)
    ap.add_argument("--n", type=int, default=1000)
    ap.add_argument("--csv", help="evaluate one frozen dataset instead of regenerating")
    a = ap.parse_args()

    if a.csv:
        df = pd.read_csv(a.csv)
        res, preds, yte = run_models(df, 0)
        conf = pd.DataFrame([{"model": k, **{m: v[m] for m in ["TP", "FP", "FN", "TN"]}} for k, v in res.items()])
        save(conf, "frozen_confusion_matrices")
        save(bootstrap(yte, preds), "frozen_bootstrap_ci")
        b, c, p = mcnemar(yte, preds["Boosted tree"][0], preds["Logistic regression"][0])
        print(f"\nMcNemar boosted tree vs logistic regression: b={b} c={c} p={p:.4f}")
        roc_figure(yte, preds, os.path.join(OUT, "roc_frozen.pdf"))
        return

    seeds = range(a.seeds)
    model_runs, abl_runs, balance = [], [], []
    for s in seeds:
        df = pd.DataFrame(gen.generate(s, a.n))
        r, preds, yte = run_models(df, s)
        model_runs.append(r); abl_runs.append(run_ablations(df, s))
        balance.append(yte.mean())
        if s == 0:
            roc_figure(yte, preds, os.path.join(OUT, "roc_seed0.pdf"))
    save(summarise(model_runs), f"baselines_{a.seeds}seeds")
    save(summarise(abl_runs), f"ablation_{a.seeds}seeds")
    print(f"\nHIGH share in test sets: mean {np.mean(balance):.3f}, range {min(balance):.3f} to {max(balance):.3f}")

    sens = []
    for t in [0.50, 0.55, 0.60, 0.65, 0.70]:
        runs, pos = [], []
        for s in seeds:
            df = pd.DataFrame(gen.generate(s, a.n))
            r, _, yte = run_models(df, s, threshold=t)
            runs.append({"Boosted tree": r["Boosted tree"], "Always HIGH": r["Always HIGH"]}); pos.append(yte.mean())
        summ = summarise(runs)
        summ.insert(0, "threshold", t); summ.insert(1, "HIGH share", f"{np.mean(pos):.2f}")
        sens.append(summ[["threshold", "HIGH share", "model", "recall", "specificity", "f1", "roc_auc"]])
    save(pd.concat(sens), f"threshold_sensitivity_{a.seeds}seeds")

if __name__ == "__main__":
    main()
