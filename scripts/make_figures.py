"""Build the paper's result figures (PDF + 300-dpi PNG) and LaTeX tables from the committed outputs.

Usage (from the repo root):  python3 scripts/make_figures.py
Needs: pip install pandas matplotlib
Writes to paper_figures/. A figure whose input file is missing is skipped and reported.
Use the PDFs in LaTeX (\\includegraphics{paper_figures/fig2_roc.pdf}); they stay sharp at any zoom.
"""
import os
import re
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

OUT = "ml/real/out"
BQ = f"{OUT}/bigquery"
DEST = "paper_figures"
BLUE, ORANGE, INK, MUTED, GRID = "#2a78d6", "#eb6834", "#0b0b0b", "#52514e", "#e6e5e0"
WIDTH = 4.8  # inches, Springer LNCS text width (~122 mm)

plt.rcParams.update({
    "font.family": "serif", "font.size": 8, "axes.titlesize": 8.5, "axes.labelsize": 8,
    "xtick.labelsize": 7.5, "ytick.labelsize": 7.5, "legend.fontsize": 7.5,
    "axes.edgecolor": MUTED, "axes.labelcolor": INK, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.spines.top": False, "axes.spines.right": False, "axes.linewidth": 0.6,
    "pdf.fonttype": 42, "savefig.bbox": "tight", "savefig.pad_inches": 0.03,
})
made, skipped = [], []


def save(fig, name):
    os.makedirs(DEST, exist_ok=True)
    fig.savefig(f"{DEST}/{name}.pdf")
    fig.savefig(f"{DEST}/{name}.png", dpi=300)
    plt.close(fig)
    made.append(name)


def grid(ax, axis="x"):
    ax.grid(axis=axis, color=GRID, lw=0.6)
    ax.set_axisbelow(True)


def md_tables(path):
    """All markdown tables in a text file, as DataFrames of strings."""
    tables, rows = [], []
    is_sep = lambda r: re.fullmatch(r"[\s|:\-]+", r) is not None
    lines = open(path, encoding="utf-8").read().splitlines() + [""]
    for i, line in enumerate(lines):
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        is_row = line.strip().startswith("|")
        # A header row (followed by a separator) starts a new table, even with no blank line before it.
        if is_row and is_sep(nxt) and rows:
            tables.append(rows); rows = []
        if is_row and not is_sep(line):
            rows.append([c.strip() for c in line.strip().strip("|").split("|")])
        elif not is_row and rows:
            tables.append(rows); rows = []
    return [pd.DataFrame(t[1:], columns=t[0]) for t in tables if len(t) > 1]


def ci(cell):
    """'0.862 [0.828, 0.896]' -> (0.862, 0.828, 0.896); '0.983' -> (0.983, nan, nan)."""
    nums = [float(x) for x in re.findall(r"-?\d+\.\d+|-?\d+", str(cell))]
    return (nums[0], nums[1], nums[2]) if len(nums) >= 3 else (nums[0] if nums else np.nan, np.nan, np.nan)


def ncrb_table(path):
    if path.endswith(".csv"):
        return pd.read_csv(path)
    return md_tables(path)[0]


def bq_eval(name):
    p = f"{BQ}/eval_{name}.csv"
    return pd.read_csv(p).iloc[0] if os.path.exists(p) else None


def need(*paths):
    missing = [p for p in paths if not os.path.exists(p)]
    return missing


# ---------------------------------------------------------------- NCRB: model comparison
def fig_ncrb_models():
    src = f"{OUT}/ncrb_results_top20.md" if os.path.exists(f"{OUT}/ncrb_results_top20.md") else f"{OUT}/ncrb_results.csv"
    if need(src):
        return skipped.append(("fig_ncrb_models", src))
    t = ncrb_table(src)
    t = t[~t["model"].str.startswith("Persistence")]  # binary score: AUC not comparable
    rows = [(m, *ci(a), *ci(p)) for m, a, p in zip(t["model"], t["roc_auc"], t["pr_auc"])]
    for name, label in [("ncrb_risk_model_v1", "Boosted tree (BigQuery ML, deployed)"),
                        ("ncrb_lr_v1", "Logistic regression (BigQuery ML)")]:
        e = bq_eval(name)
        if e is not None:
            rows.append((label, float(e["roc_auc"]), np.nan, np.nan, np.nan, np.nan, np.nan))
    rows = rows[::-1]
    fig, axes = plt.subplots(1, 2, figsize=(WIDTH, 0.28 * len(rows) + 0.7), sharey=True)
    y = np.arange(len(rows))
    for ax, k, title in [(axes[0], 1, "ROC-AUC"), (axes[1], 4, "PR-AUC")]:
        for i, r in enumerate(rows):
            v, lo, hi = r[k], r[k + 1], r[k + 2]
            if np.isnan(v):
                continue
            deployed = "deployed" in r[0]
            if not np.isnan(lo):
                ax.plot([lo, hi], [i, i], color=MUTED, lw=1.2, solid_capstyle="round")
            ax.plot(v, i, "o", ms=5, color=ORANGE if deployed else BLUE, mec="white", mew=0.8)
        ax.set_title(title, loc="left", color=INK)
        grid(ax)
    for ax, k in [(axes[0], 1), (axes[1], 4)]:
        lows = [r[k + 1] if not np.isnan(r[k + 1]) else r[k] for r in rows if not np.isnan(r[k])]
        ax.set_xlim(min(lows) - 0.01, 1.0)
    axes[0].set_yticks(y, [r[0] for r in rows])
    axes[0].tick_params(axis="y", length=0)
    fig.text(0.01, -0.02, "Dots: point estimate. Lines: 95% bootstrap interval. BigQuery ML rows have no interval.",
             fontsize=6.5, color=MUTED)
    save(fig, "fig_ncrb_models")


# ---------------------------------------------------------------- Fig. 2: ROC
def fig_roc():
    bt, lr = f"{BQ}/roc_ncrb_risk_model_v1.csv", f"{BQ}/roc_ncrb_lr_v1.csv"
    if need(bt, lr):
        return skipped.append(("fig2_roc", f"{bt}, {lr}"))

    def high_curve(path):
        # BigQuery ML used LOW as the positive class; flip each point to the HIGH class.
        d = pd.read_csv(path)
        pts = np.r_[[[0, 0]], np.c_[1 - d["recall"], 1 - d["false_positive_rate"]], [[1, 1]]]
        pts = pts[np.lexsort((pts[:, 1], pts[:, 0]))]
        return pts[:, 0], pts[:, 1], float(np.sum(np.diff(pts[:, 0]) * (pts[1:, 1] + pts[:-1, 1]) / 2))

    fig, ax = plt.subplots(figsize=(WIDTH * 0.62, WIDTH * 0.62))
    for path, name, c in [(bt, "Boosted tree (deployed)", ORANGE), (lr, "Logistic regression", BLUE)]:
        x, y, auc = high_curve(path)
        ax.plot(x, y, color=c, lw=1.6, label=f"{name}, AUC {auc:.3f}")
    src = f"{OUT}/ncrb_results_top20.md"
    if os.path.exists(src):
        t = ncrb_table(src)
        p = t[t["model"].str.startswith("Persistence")]
        if len(p):
            r, s = ci(p.iloc[0]["recall"])[0], ci(p.iloc[0]["specificity"])[0]
            ax.plot(1 - s, r, "s", ms=5, color=INK, label="Persistence (HIGH last year)")
    ax.plot([0, 1], [0, 1], color=MUTED, lw=0.7, ls=":", label="Chance")
    ax.set_xlabel("False positive rate"); ax.set_ylabel("True positive rate (HIGH districts)")
    ax.set_xlim(0, 1); ax.set_ylim(0, 1.01); ax.set_aspect("equal")
    grid(ax, "both")
    ax.legend(loc="lower right", frameon=False)
    save(fig, "fig2_roc")


# ---------------------------------------------------------------- NCRB: label threshold sensitivity
def fig_sensitivity():
    files = {s: f"{OUT}/ncrb_results_top{s}.md" for s in (10, 20, 30)}
    have = {s: p for s, p in files.items() if os.path.exists(p)}
    if len(have) < 2:
        return skipped.append(("fig_ncrb_sensitivity", ", ".join(files.values())))
    keep = {"Last year's rank (top 20% flagged)": ("Last year's rank", INK, "s"),
            "Logistic regression": ("Logistic regression", BLUE, "o"),
            "Boosted tree": ("Boosted tree", ORANGE, "o")}
    fig, ax = plt.subplots(figsize=(WIDTH * 0.62, 2.2))
    shares = sorted(have)
    for j, (model, (label, c, m)) in enumerate(keep.items()):
        pts = []
        for s in shares:
            t = ncrb_table(have[s])
            r = t[t["model"].str.replace("20%", f"{s}%") .str.startswith(model.split(" (")[0])]
            if len(r):
                pts.append((s, *ci(r.iloc[0]["roc_auc"])))
        if not pts:
            continue
        pts = np.array(pts, dtype=float)
        x = pts[:, 0] + (j - 1) * 0.6
        ax.plot(x, pts[:, 1], color=c, lw=1.4, marker=m, ms=5, mec="white", mew=0.8, label=label)
        ok = ~np.isnan(pts[:, 2])
        ax.vlines(x[ok], pts[ok, 2], pts[ok, 3], color=c, lw=1)
    ax.set_xticks(shares, [f"Top {s}%" for s in shares])
    ax.set_ylabel("ROC-AUC (95% interval)")
    ax.set_xlabel("Share of districts labelled HIGH")
    ax.set_xlim(shares[0] - 3, shares[-1] + 3)
    grid(ax, "y")
    ax.legend(frameon=False, loc="lower center", bbox_to_anchor=(0.5, 1.0), ncol=3, handlelength=1.5)
    save(fig, "fig_ncrb_sensitivity")


# ---------------------------------------------------------------- NCRB: feature importance
def fig_importance():
    p = f"{BQ}/importance_bt.csv"
    if need(p):
        return skipped.append(("fig_feature_importance", p))
    d = pd.read_csv(p).sort_values("importance_gain", ascending=False).head(10)[::-1]
    short = {"assault_on_women_with_intent_to_outrage_her_modesty": "Assault on modesty",
             "cruelty_by_husband_or_his_relatives": "Cruelty by husband/relatives",
             "insult_to_modesty_of_women": "Insult to modesty", "kidnapping_and_abduction": "Kidnapping",
             "importation_of_girls": "Importation of girls", "dowry_deaths": "Dowry deaths", "rape": "Rape"}

    def nice(f):
        if f == "was_high_lag1": return "HIGH last year"
        if f == "pct_change_lag1": return "Rank change (1 yr)"
        if f.startswith("pct_lag"): return f"Rank, {f[-1]} yr ago"
        if f.endswith("_share_lag1"):
            b = f[:-len("_share_lag1")]
            return f"{short.get(b, b.replace('_', ' ').capitalize())} share"
        return f.replace("_", " ").capitalize()
    fig, ax = plt.subplots(figsize=(WIDTH * 0.8, 0.24 * len(d) + 0.5))
    share = d["importance_gain"] / d["importance_gain"].sum()
    ax.barh(range(len(d)), share, color=BLUE, height=0.62)
    for i, v in enumerate(share):
        ax.text(v + 0.005, i, f"{v:.0%}" if v >= 0.005 else "<1%", va="center", fontsize=7, color=INK)
    ax.set_yticks(range(len(d)), [nice(f) for f in d["feature"]])
    ax.tick_params(axis="y", length=0)
    ax.set_xlabel("Share of total gain (top 10 features)")
    ax.set_xlim(0, share.max() * 1.18)
    grid(ax)
    save(fig, "fig_feature_importance")


# ---------------------------------------------------------------- LAPD
def la_counts():
    p = f"{OUT}/la_run_log.txt"
    if not os.path.exists(p):
        return None, None
    cats = bands = None
    for t in md_tables(p):
        cols = [c.lower() for c in t.columns]
        if cols[0] == "category":
            cats = t
        elif cols[0] == "band":
            bands = t
    return cats, bands


def fig_la_counts():
    cats, bands = la_counts()
    if cats is None or bands is None:
        return skipped.append(("fig_la_counts", f"{OUT}/la_run_log.txt"))
    fig, axes = plt.subplots(1, 2, figsize=(WIDTH, 1.9), gridspec_kw={"width_ratios": [1.25, 1]})
    c = cats.copy(); c["n"] = c.iloc[:, 1].astype(int); c = c.sort_values("n")
    axes[0].barh(c.iloc[:, 0], c["n"], color=BLUE, height=0.62)
    for i, v in enumerate(c["n"]):
        axes[0].text(v + c["n"].max() * 0.02, i, f"{v:,}", va="center", fontsize=7, color=INK)
    axes[0].set_xlim(0, c["n"].max() * 1.25); axes[0].set_title("By offence type", loc="left")
    axes[0].tick_params(axis="y", length=0); axes[0].set_xticks([])
    axes[0].spines["bottom"].set_visible(False)
    labels = ["00-06", "06-12", "12-18", "18-24"]
    b = bands.iloc[:, 1].astype(int).to_numpy()
    axes[1].bar(labels[:len(b)], b, color=BLUE, width=0.62)
    for i, v in enumerate(b):
        axes[1].text(i, v + b.max() * 0.02, f"{v:,}", ha="center", fontsize=7, color=INK)
    axes[1].set_ylim(0, b.max() * 1.18); axes[1].set_yticks([])
    axes[1].spines["left"].set_visible(False)
    axes[1].set_title("By time of day (hours)", loc="left")
    save(fig, "fig_la_counts")


def fig_la_models():
    p = f"{OUT}/la_results.csv"
    if need(p):
        return skipped.append(("fig_la_models", p))
    d = pd.read_csv(p)
    hit = [c for c in d.columns if c.startswith("hit_rate")][0]
    d = d.sort_values(hit)
    fig, ax = plt.subplots(figsize=(WIDTH, 0.3 * len(d) + 0.55))
    colors = [ORANGE if m == "Boosted tree" else BLUE for m in d["model"]]
    ax.barh(d["model"], d[hit], color=colors, height=0.62)
    for i, (v, pai) in enumerate(zip(d[hit], d["PAI"])):
        ax.text(v + 0.004, i, f"{v:.1%}  (PAI {pai:.2f})", va="center", fontsize=7, color=INK)
    ax.set_xlim(0, d[hit].max() * 1.35)
    ax.set_xlabel("Share of next-month incidents in the top 5% of cells (2023)")
    ax.tick_params(axis="y", length=0)
    grid(ax)
    save(fig, "fig_la_models")


# ---------------------------------------------------------------- Chatbot
def chatbot_tables(path):
    t = md_tables(path)
    per = next((x for x in t if x.columns[0] == "Intent"), None)
    thr = next((x for x in t if x.columns[0] == "Threshold"), None)
    return per, thr


def fig_chatbot_f1():
    after = "scripts/chatbot_eval_after.txt"
    before = next((p for p in ("scripts/chatbot_eval_before.txt", "scripts/chatbot_eval_results.txt")
                   if os.path.exists(p)), "")
    if need(after):
        return skipped.append(("fig_chatbot_f1", after))
    a, _ = chatbot_tables(after)
    b = chatbot_tables(before)[0] if os.path.exists(before) else None
    names = a["Intent"].tolist()[::-1]
    y = np.arange(len(names))
    fig, ax = plt.subplots(figsize=(WIDTH, 0.3 * len(names) + 0.6))
    h = 0.36 if b is not None else 0.6
    av = a.set_index("Intent").loc[names, "F1"].astype(float)
    if b is not None:
        bv = b.set_index("Intent").reindex(names)["F1"].astype(float)
        ax.barh(y + h / 2 + 0.02, bv, height=h, color=BLUE, label="Before")
        ax.barh(y - h / 2 - 0.02, av, height=h, color=ORANGE, label="After")
        ax.legend(frameon=False, loc="lower right", ncol=2, bbox_to_anchor=(1, 1.0))
    else:
        ax.barh(y, av, height=h, color=BLUE)
    for i, v in enumerate(av):
        ax.text(v + 0.01, i - (h / 2 + 0.02 if b is not None else 0), f"{v:.2f}", va="center", fontsize=6.5, color=INK)
    n = a.set_index("Intent").loc[names, "n"]
    ax.set_yticks(y, [f"{k} (n={v})" for k, v in zip(names, n)])
    ax.tick_params(axis="y", length=0)
    ax.set_xlim(0, 1.08); ax.set_xlabel("F1 on held-out queries")
    grid(ax)
    save(fig, "fig_chatbot_f1")


def fig_chatbot_threshold():
    after = "scripts/chatbot_eval_after.txt"
    if need(after):
        return skipped.append(("fig_chatbot_threshold", after))
    _, t = chatbot_tables(after)
    x = t["Threshold"].astype(float)
    fig, ax = plt.subplots(figsize=(WIDTH * 0.62, 2.2))
    ax.plot(x, t["Referral recall"].astype(float), color=BLUE, lw=1.6, marker="o", ms=4.5, mec="white",
            label="Queries it should refer that it refers")
    ax.plot(x, t["In-scope answered correctly"].astype(float), color=ORANGE, lw=1.6, marker="o", ms=4.5,
            mec="white", label="In-scope queries answered correctly")
    chosen = float(os.environ.get("THRESHOLD", 0.5))
    ax.axvline(chosen, color=MUTED, lw=0.8, ls="--")
    ax.text(chosen + 0.01, 0.04, f"chosen: {chosen}", fontsize=7, color=MUTED)
    ax.set_xlabel("Confidence threshold for referral"); ax.set_ylim(0, 1.05)
    grid(ax, "y")
    ax.legend(frameon=False, loc="upper center", bbox_to_anchor=(0.5, 1.28))
    save(fig, "fig_chatbot_threshold")


# ---------------------------------------------------------------- LaTeX tables
def tex_tables():
    os.makedirs(f"{DEST}/tables", exist_ok=True)
    src = f"{OUT}/ncrb_results_top20.md"
    if os.path.exists(src):
        t = ncrb_table(src)
        fmt = lambda c: "{:.3f} [{:.3f}, {:.3f}]".format(*ci(c)) if not np.isnan(ci(c)[1]) else f"{ci(c)[0]:.3f}"
        lines = [r"\begin{tabular}{lcccc}", r"\hline", r"Model & Recall & Specificity & ROC-AUC & PR-AUC \\", r"\hline"]
        for _, r in t.iterrows():
            lines.append(f"{r['model']} & {fmt(r['recall'])} & {fmt(r['specificity'])} & {fmt(r['roc_auc'])} & {fmt(r['pr_auc'])} \\\\")
        hm = f"{BQ}/high_class_metrics.csv"
        if os.path.exists(hm):
            rows = [l.split(",") for l in open(hm).read().splitlines() if l and not l.startswith("model")]
            for m, prec, rec, spec, *_ in rows:
                e = bq_eval(m)
                auc = f"{float(e['roc_auc']):.3f}" if e is not None else "--"
                label = "Boosted tree (BigQuery ML, deployed)" if "risk" in m else "Logistic regression (BigQuery ML)"
                lines.append(f"{label} & {float(rec):.3f} & {float(spec):.3f} & {auc} & -- \\\\")
        lines += [r"\hline", r"\end{tabular}"]
        open(f"{DEST}/tables/table3_ncrb.tex", "w").write("\n".join(lines).replace("%", r"\%") + "\n")
        made.append("tables/table3_ncrb.tex")
    if os.path.exists(f"{OUT}/la_results.csv"):
        d = pd.read_csv(f"{OUT}/la_results.csv")
        hit = [c for c in d.columns if c.startswith("hit_rate")][0]
        lines = [r"\begin{tabular}{lcccc}", r"\hline", r"Model & ROC-AUC & PR-AUC & Hit rate (top 5\%) & PAI \\", r"\hline"]
        lines += [f"{r['model']} & {r['roc_auc']:.3f} & {r['pr_auc']:.3f} & {r[hit]:.3f} & {r['PAI']:.2f} \\\\" for _, r in d.iterrows()]
        lines += [r"\hline", r"\end{tabular}"]
        open(f"{DEST}/tables/table4_lapd.tex", "w").write("\n".join(lines) + "\n")
        made.append("tables/table4_lapd.tex")
    if os.path.exists("scripts/chatbot_eval_after.txt"):
        a, _ = chatbot_tables("scripts/chatbot_eval_after.txt")
        lines = [r"\begin{tabular}{lcccc}", r"\hline", r"Intent & $n$ & Precision & Recall & F1 \\", r"\hline"]
        lines += [f"{r['Intent'].replace('_', chr(92) + '_')} & {r['n']} & {r['Precision']} & {r['Recall']} & {r['F1']} \\\\" for _, r in a.iterrows()]
        lines += [r"\hline", r"\end{tabular}"]
        open(f"{DEST}/tables/table_chatbot.tex", "w").write("\n".join(lines) + "\n")
        made.append("tables/table_chatbot.tex")


if __name__ == "__main__":
    if not os.path.isdir(OUT):
        sys.exit("Run from the repo root (the folder with ml/ and scripts/).")
    for f in (fig_ncrb_models, fig_roc, fig_sensitivity, fig_importance, fig_la_counts,
              fig_la_models, fig_chatbot_f1, fig_chatbot_threshold, tex_tables):
        try:
            f()
        except Exception as e:  # one bad input should not stop the other figures
            skipped.append((f.__name__, f"error: {e}"))
    print(f"Written to {DEST}/:")
    for m in made:
        print("  ", m)
    for name, why in skipped:
        print(f"  SKIPPED {name}: {why}")
