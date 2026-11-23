"""Seeded synthetic incident generator for SafeHer. Kept only to reproduce the submitted paper's synthetic results."""
import argparse
import csv
import os
import random

CITIES = {  # name: (lat, lng) approximate city centres
    "Thiruvananthapuram": (8.5241, 76.9366),
    "Kollam": (8.8932, 76.6141),
    "Alappuzha": (9.4981, 76.3388),
    "Kottayam": (9.5916, 76.5222),
    "Kochi": (9.9312, 76.2673),
    "Thrissur": (10.5276, 76.2144),
    "Palakkad": (10.7867, 76.6548),
    "Malappuram": (11.0510, 76.0711),
    "Kozhikode": (11.2588, 75.7804),
    "Kannur": (11.8745, 75.3704),
}
CITY_SPREAD_DEG = 0.03          # std dev of a report around its city centre
CATEGORY_PROBS = {              # share of each category
    "Harassment": 0.30,
    "Eve Teasing": 0.20,
    "Stalking": 0.20,
    "Unsafe Area": 0.15,
    "Assault": 0.15,
}
P_NIGHT = 0.50                  # share of reports between 21:00 and 04:59
P_WEEKEND = 0.40                # share of reports on Saturday or Sunday
NOISE = 0.15                    # uniform noise in [-NOISE, +NOISE]
THRESHOLD = 0.60
TEST_FRACTION = 0.20

# Table 2 weights
CATEGORY_W = {"Assault": 0.55, "Stalking": 0.45, "Eve Teasing": 0.35,
              "Harassment": 0.25, "Unsafe Area": 0.15}

def hour_weight(h):
    if 0 <= h <= 4:
        return 0.25
    if 21 <= h <= 23:
        return 0.20
    if 18 <= h <= 20:
        return 0.10
    return 0.0

def day_weight(d):
    # d follows JavaScript getDay(): 0 = Sunday ... 6 = Saturday
    if d in (0, 6):
        return 0.10
    if d == 5:
        return 0.05
    return 0.0

def clean_score(category, hour, day):
    """Noise-free score. Used as the rule-oracle baseline."""
    return CATEGORY_W[category] + hour_weight(hour) + day_weight(day)

def sample_row(rng):
    city = rng.choice(list(CITIES))
    clat, clng = CITIES[city]
    lat = round(rng.gauss(clat, CITY_SPREAD_DEG), 3)   # 111 m storage grid
    lng = round(rng.gauss(clng, CITY_SPREAD_DEG), 3)
    category = rng.choices(list(CATEGORY_PROBS), weights=CATEGORY_PROBS.values())[0]
    if rng.random() < P_NIGHT:
        hour = rng.choice([21, 22, 23, 0, 1, 2, 3, 4])
    else:
        hour = rng.randint(5, 20)
    if rng.random() < P_WEEKEND:
        day = rng.choice([0, 6])
    else:
        day = rng.randint(1, 5)
    score = clean_score(category, hour, day) + rng.uniform(-NOISE, NOISE)
    return {
        "city": city, "lat": lat, "lng": lng, "category": category,
        "hour_of_day": hour, "day_of_week": day,
        "risk_score": round(score, 4),
        "risk_label": "HIGH" if score >= THRESHOLD else "LOW",
    }

def stratified_split(rows, rng, test_fraction):
    """Assign split = TRAIN/TEST, stratified on the label, frozen by seed."""
    for label in ("HIGH", "LOW"):
        idx = [i for i, r in enumerate(rows) if r["risk_label"] == label]
        rng.shuffle(idx)
        n_test = round(len(idx) * test_fraction)
        for k, i in enumerate(idx):
            rows[i]["split"] = "TEST" if k < n_test else "TRAIN"
    return rows

def generate(seed, n):
    rng = random.Random(seed)
    rows = [sample_row(rng) for _ in range(n)]
    return stratified_split(rows, rng, TEST_FRACTION)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--n", type=int, default=1000)
    ap.add_argument("--out", default="data/incidents_seed42.csv")
    args = ap.parse_args()
    rows = generate(args.seed, args.n)
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    high = sum(r["risk_label"] == "HIGH" for r in rows)
    test = sum(r["split"] == "TEST" for r in rows)
    print(f"wrote {len(rows)} rows to {args.out}: HIGH={high} ({high/len(rows):.1%}), TEST={test}")

if __name__ == "__main__":
    main()
