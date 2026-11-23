#!/usr/bin/env bash
# One-time setup of a new project. Usage: bash scripts/setup_new_project.sh NEW_PROJECT_ID
set -euo pipefail
P="${1:?Usage: bash scripts/setup_new_project.sh NEW_PROJECT_ID}"
gcloud config set project "$P"

echo "== APIs"
gcloud services enable firestore.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com \
  run.googleapis.com artifactregistry.googleapis.com eventarc.googleapis.com pubsub.googleapis.com \
  cloudscheduler.googleapis.com bigquery.googleapis.com dialogflow.googleapis.com \
  identitytoolkit.googleapis.com firebase.googleapis.com

echo "== Firestore (asia-south1, same as before)"
gcloud firestore databases create --location=asia-south1 --type=firestore-native || echo "  (already exists)"

echo "== BigQuery dataset"
bq --location=asia-south1 mk --dataset "$P:safeher" || echo "  (already exists)"
bq query --use_legacy_sql=false "
CREATE TABLE IF NOT EXISTS \`$P.safeher.incidents_live\` (
  incident_id STRING, lat FLOAT64, lng FLOAT64, category STRING,
  hour_of_day INT64, day_of_week INT64, reported_hour TIMESTAMP)
PARTITION BY DATE(reported_hour) OPTIONS (partition_expiration_days = 365)"

echo "== Dialogflow role for the Cloud Functions runtime account"
NUM=$(gcloud projects describe "$P" --format='value(projectNumber)')
gcloud projects add-iam-policy-binding "$P" --member="serviceAccount:$NUM-compute@developer.gserviceaccount.com" \
  --role=roles/dialogflow.client --condition=None >/dev/null && echo "  granted"

echo
echo "Still to do by hand in the Firebase console ($P):"
echo "  1. Upgrade to the Blaze plan (Cloud Functions need it). Set a budget alert, e.g. Rs 500."
echo "  2. Authentication > Sign-in method > enable Anonymous."
echo "Then: node dialogflow/create_agent.js $P"
