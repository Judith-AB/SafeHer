"""Person 2's paper figures and tables: API latency, privacy-rule tests, retention, retraining runs.

Usage (from the repo root):  python3 scripts/make_backend_figures.py
Needs: pip install pandas matplotlib   (shares styling with scripts/make_figures.py)
Inputs, each optional (a missing one is skipped and reported):
  scripts/latency_cold.txt, scripts/latency_warm.txt   output of scripts/latency_test.js
  scripts/test_rules.txt, scripts/test_helpers.txt     output of the two test suites
  scripts/model_history.csv                            output of scripts/export_model_history.js
  functions/index.js                                   retention periods are read from the code
Writes to paper_figures/ (PDF + 300-dpi PNG) and paper_figures/tables/.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_figures as mf  # noqa: E402
from make_figures import BLUE, ORANGE, INK, MUTED, WIDTH, grid, md_tables, save  # noqa: E402

import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

TEX = f"{mf.DEST}/tables"


def write_tex(name, header, rows, cols="l" + "c" * 10):
    os.makedirs(TEX, exist_ok=True)
    spec = cols[:len(header)]
    lines = [rf"\begin{{tabular}}{{{spec}}}", r"\hline", " & ".join(header) + r" \\", r"\hline"]
    lines += [" & ".join(str(c) for c in r) + r" \\" for r in rows]
    lines += [r"\hline", r"\end{tabular}"]
    open(f"{TEX}/{name}.tex", "w").write("\n".join(lines) + "\n")
    mf.made.append(f"tables/{name}.tex")


def latency(path):
    if not os.path.exists(path):
        return None
    t = next((x for x in md_tables(path) if x.columns[0] == "Concurrency"), None)
    if t is None:
        return None
    return t.apply(pd.to_numeric, errors="coerce")


# ---------------------------------------------------------------- latency
def fig_latency():
    runs = {k: latency(f"scripts/latency_{k}.txt") for k in ("cold", "warm")}
    runs = {k: v for k, v in runs.items() if v is not None}
    if not runs:
        return mf.skipped.append(("fig_latency", "scripts/latency_cold.txt / latency_warm.txt"))
    colors = {"cold": BLUE, "warm": ORANGE}
    labels = {"cold": "First run after deploy", "warm": "Repeat run (cache warm)"}
    fig, axes = plt.subplots(1, 2, figsize=(WIDTH, 2.1), sharey=True)
    for ax, col, title in [(axes[0], "p50 ms", "Median (p50)"), (axes[1], "p95 ms", "95th percentile (p95)")]:
        for k, d in runs.items():
            ax.plot(d["Concurrency"], d[col], color=colors[k], lw=1.6, marker="o", ms=4.5, mec="white",
                    label=labels[k])
        ax.set_xscale("log")
        ticks = sorted(set().union(*[set(d["Concurrency"]) for d in runs.values()]))
        ax.set_xticks(ticks, [str(int(t)) for t in ticks])
        ax.minorticks_off()
        ax.set_title(title, loc="left")
        ax.set_xlabel("Concurrent clients")
        grid(ax, "y")
    axes[0].set_ylabel("Response time (ms)")
    axes[0].set_ylim(0, None)
    if len(runs) > 1:
        axes[0].legend(frameon=False, loc="lower left", bbox_to_anchor=(0, 1.1), ncol=2)
    save(fig, "fig_latency")

    rows = []
    for k, d in runs.items():
        for _, r in d.iterrows():
            err = r["Errors"] / r["Requests"] if r["Requests"] else 0
            rows.append([labels[k], int(r["Concurrency"]), int(r["Requests"]), f"{err:.1%}".replace("%", r"\%"),
                         int(r["p50 ms"]), int(r["p95 ms"]), int(r["p99 ms"])])
    write_tex("table_latency", ["Run", "Clients", "Requests", "Errors", "p50 (ms)", "p95 (ms)", "p99 (ms)"], rows)


# ---------------------------------------------------------------- tests
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def test_results(path):
    """(name, passed) from node --test output, TAP (piped) or spec (terminal) format."""
    out = []
    for line in open(path, encoding="utf-8", errors="ignore"):
        line = ANSI.sub("", line).rstrip()
        m = re.match(r"^(not ok|ok) \d+ - (.+?)(?: # .*)?$", line)
        if m:
            out.append((m.group(2), m.group(1) == "ok"))
            continue
        m = re.match(r"^\s*([✔✖])\s+(.+?)(?:\s+\([\d.]+ms\))?$", line)
        if m:
            out.append((m.group(2), m.group(1) == "✔"))
    return out


def tex_tests():
    suites = [("Firestore rule", "scripts/test_rules.txt"), ("Server helper", "scripts/test_helpers.txt")]
    rows = []
    for kind, p in suites:
        if not os.path.exists(p):
            mf.skipped.append((f"tests ({kind})", p))
            continue
        res = test_results(p)
        if not res:
            mf.skipped.append((f"tests ({kind})", f"{p}: no test lines found"))
        rows += [[kind, n.replace("~", r"$\sim$").replace("%", r"\%"), "Pass" if ok else "\\textbf{Fail}"]
                 for n, ok in res]
    if rows:
        write_tex("table_privacy_tests", ["Layer", "Check", "Result"], rows, cols="llc")
        passed = sum(r[2] == "Pass" for r in rows)
        print(f"   tests: {passed}/{len(rows)} passed")


# ---------------------------------------------------------------- retention (read from the code)
def tex_retention():
    p = "functions/index.js"
    if not os.path.exists(p):
        return mf.skipped.append(("table_retention", p))
    m = re.search(r"RETENTION_DAYS\s*=\s*\{([^}]*)\}", open(p, encoding="utf-8").read())
    if not m:
        return mf.skipped.append(("table_retention", "RETENTION_DAYS not found in functions/index.js"))
    days = dict(re.findall(r"(\w+)\s*:\s*(\d+)", m.group(1)))
    what = {
        "incident": ("incidents", "Category, location rounded to 3 decimals, IST hour, no user ID"),
        "sos": ("sos\\_events", "Rounded location and time; no user ID"),
        "legal": ("unresolved\\_legal\\_queries", "Query text the bot could not answer, for referral"),
    }
    rows = [[what.get(k, (k, ""))[0], what.get(k, (k, ""))[1], v] for k, v in days.items()]
    write_tex("table_retention", ["Collection", "What is kept", "Deleted after (days)"], rows, cols="llc")


# ---------------------------------------------------------------- retraining runs
def tex_retraining():
    p = "scripts/model_history.csv"
    if not os.path.exists(p):
        return mf.skipped.append(("table_retraining", p))
    d = pd.read_csv(p)
    if d.empty:
        return mf.skipped.append(("table_retraining", f"{p} has no runs yet"))
    f = lambda v: "--" if pd.isna(v) or v == "" else f"{float(v):.3f}"
    rows = [[r["at"], r["candidate"].split(".")[-1].replace("_", r"\_"), f(r["cand_roc_auc"]), f(r["prev_roc_auc"]),
             "Promoted" if str(r["promoted"]).lower() == "true" else "Rejected"] for _, r in d.iterrows()]
    write_tex("table_retraining", ["Date", "Candidate", "AUC", "Previous AUC", "Gate"], rows, cols="llccc")


if __name__ == "__main__":
    if not os.path.isdir("scripts"):
        sys.exit("Run from the repo root (the folder with functions/ and scripts/).")
    mf.made.clear(); mf.skipped.clear()
    for fn in (fig_latency, tex_tests, tex_retention, tex_retraining):
        try:
            fn()
        except Exception as e:
            mf.skipped.append((fn.__name__, f"error: {e}"))
    print(f"Written to {mf.DEST}/:")
    for m in mf.made:
        print("  ", m)
    for name, why in mf.skipped:
        print(f"  SKIPPED {name}: {why}")
