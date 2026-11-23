# SafeHer
### Women's Safety & Legal Information Platform (research prototype)

**SDGs addressed:** SDG 5 Gender Equality, SDG 16 Peace, Justice and Strong Institutions

## Overview

SafeHer is a proof-of-concept women's safety app: anonymous incident reporting with
location generalisation, a district risk map for Kerala from a BigQuery ML model trained on **real NCRB
district-level data**, a Dialogflow ES legal-information bot with a referral fallback, and a 112 SOS shortcut.

## What is actually in this repository

| Part | Path | What it does |
| --- | --- | --- |
| Flutter app | `app/lib` | Report, heatmap, legal bot, analytics, SOS screens |
| Cloud Functions | `functions/index.js` | `onIncidentCreated`, `onSosTriggered`, `detectLegalIntent`, `escalateLegalQuery`, `getPredictiveHeatmap`, `scheduledRetrainRiskModel` |
| Firestore rules | `firestore.rules`, `rules-test/` | Create-only clients, rounded coordinates enforced |
| ML package | `ml/real/` | NCRB and LAPD real-data pipelines, BigQuery ML SQL, baselines |
| Scripts | `scripts/` | Latency test, chatbot evaluation and test set |

Services used: Firebase Auth (anonymous), Firestore, Cloud Functions (2nd gen), Cloud Scheduler,
BigQuery ML (boosted tree), Dialogflow ES, OpenStreetMap tiles via `flutter_map`.
Not used, despite earlier versions of this README: Google Maps SDK, Dialogflow CX,
Gmail SMTP alerts, the BigQuery export extension, Looker Studio.

## Data flow

1. The app rounds GPS to 3 decimals (~111 m) and writes an incident with no user ID.
   Firestore rules reject unrounded coordinates and unknown fields.
2. `onIncidentCreated` validates the report, truncates the time to the hour (IST), sets a
   365-day `expireAt`, updates aggregate counters and inserts a row into `safeher.incidents_live`.
3. `getPredictiveHeatmap` scores next-year features for each Kerala district with the current
   model and caches the result per model version.
4. `scheduledRetrainRiskModel` (1st of each month, 00:00 UTC) trains a dated candidate on the NCRB
   panel, evaluates it on held-out years, and promotes it only if it passes the gate.
5. The legal bot calls Dialogflow through `detectLegalIntent`. Low confidence or the fallback
   intent triggers a referral message; the question is stored without identity for 90 days.

## Reproduce the paper

See `ml/README.md` for the experiments and `DEPLOY.md` for setup.

## Limitations

The model predicts recorded (not actual) crime: NCRB counts reflect reporting rates and
district population, and the district-year data stops at 2014. App reports are stored but not
yet used for training. The legal bot gives general
information, not legal advice, and no human replies to referred questions.
