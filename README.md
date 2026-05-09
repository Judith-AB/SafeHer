# SafeHer 
### Women's Safety & Legal Aid Platform

> A cross-platform mobile application empowering women with anonymous incident reporting, real-time safety heatmaps, AI-powered legal guidance, and emergency SOS alerts — built on Flutter and Google Cloud Platform.

**SDGs Addressed:** SDG 5 — Gender Equality &nbsp;|&nbsp; SDG 16 — Peace, Justice & Strong Institutions  

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Application Workflows](#application-workflows)
- [GCP Services](#gcp-services)
- [SDG Alignment](#sdg-alignment)
- [Getting Started](#getting-started)

---

## Overview

Gender-based violence and limited access to legal justice remain persistent challenges in urban India. Women in high-risk situations often lack anonymous, accessible, and fast tools to report incidents, seek guidance, or alert trusted contacts.

SafeHer addresses this gap through a cross-platform mobile application integrating four core GCP services — **Google Maps SDK**, **Dialogflow CX**, **BigQuery**, and **Cloud Functions** — alongside Firebase to deliver a complete, real-time women's safety ecosystem.

---

## Features

| Feature | Description |
|---|---|
| 🗺️ **Safety Heatmap** | Live map visualising incident density from anonymised report data |
| 🤖 **Legal Aid Chatbot** | AI chatbot trained on Indian women's rights and FIR procedures |
| 📊 **Incident Analytics** | SQL-powered pattern detection on aggregated incident data |
| 🆘 **SOS Emergency Alert** | One-hold button that emails live location to emergency contacts |
| 🔒 **Anonymous Reporting** | Firebase Anonymous Auth — no name, phone, or email required |

---

## Tech Stack

- **Frontend:** Flutter (cross-platform — Android & iOS)
- **Backend:** Firebase (Firestore, Authentication, Cloud Functions, Hosting)
- **Cloud:** Google Cloud Platform
- **AI/ML:** Dialogflow CX (Natural Language Understanding)
- **Analytics:** BigQuery + Looker Studio
- **Maps:** Google Maps SDK for Flutter
- **Notifications:** Gmail SMTP via Cloud Functions

---

## Architecture

```
User (Flutter App)
       │
       ├── Anonymous Auth ──────────────────► Firebase Auth
       │
       ├── Incident Report ─────────────────► Firestore (/incidents)
       │                                           │
       │                                           ├── Cloud Function (onIncidentCreated)
       │                                           │       └── PII stripping, GeoPoint validation
       │                                           │
       │                                           └── BigQuery Extension (auto-stream)
       │                                                   └── SQL Analytics
       │
       ├── Safety Heatmap ──────────────────► Firestore snapshot → Maps SDK Heatmap Layer
       │
       ├── SOS Button ──────────────────────► Cloud Function (sendSOSAlert)
       │                                           └── Gmail SMTP → Emergency Contacts
       │
       └── Legal Chatbot ───────────────────► Dialogflow CX API
                                                   └── Intent matching → Legal guidance response
```

---

## Application Workflows

### 1. Anonymous Incident Reporting
1. User taps **Report Incident** — Firebase Anonymous Auth assigns a unique UID silently (no personal info stored).
2. User selects incident type (harassment, stalking, unsafe area, violence, other) and captures GPS coordinates.
3. Report is written to Firestore → `onIncidentCreated` Cloud Function fires, validates GeoPoint, and strips any PII.
4. Firestore Extension streams the document to BigQuery; the heatmap re-renders in real time for all users nearby.

### 2. SOS Emergency Alert
1. User **holds the SOS button for 2 seconds** (long-press prevents accidental triggers).
2. App captures current GPS location and calls the `sendSOSAlert` Cloud Function.
3. Function reads pre-saved emergency contacts from Firestore and dispatches email alerts via Gmail SMTP.
4. Email contains: name, timestamp, and a Google Maps link with live coordinates.

### 3. Legal Aid Chatbot
1. User opens the chatbot and types a legal query (e.g., *"What are my rights if my husband is abusive?"*).
2. Flutter sends the message to Dialogflow CX via HTTP POST.
3. Dialogflow NLU matches the intent (e.g., `domestic_violence_rights`), extracts entities, and returns a response with relevant law sections, helpline numbers, and next steps.
4. Multi-turn conversation is supported — Dialogflow CX maintains session context.

### 4. BigQuery Analytics
1. The Firebase **Export Collections to BigQuery** extension auto-mirrors every incident write.
2. SQL queries surface patterns: incident counts by type, peak unsafe hours, top localities.
3. Results are visualised in Looker Studio and optionally embedded in the app's **Community Stats** screen.

---

## GCP Services

### Google Maps SDK — Safety Heatmap
- Every reported `GeoPoint` is read from Firestore and passed to the Maps Heatmap layer.
- Red = high-density incident zones; Green = low-risk areas.
- **Package:** `google_maps_flutter`
- **Free tier:** $200/month Maps credit (typical project usage < $5/month)

### Dialogflow CX — Legal Aid Chatbot
- Trained intents cover: POCSO Act, Domestic Violence Act, POSH Act (workplace harassment), how to file an FIR, and emergency helplines (Mahila Helpline 181, Police 100).
- **Package:** `dialog_flowtter`
- **Free tier:** Covered by $600 GCP trial credit

### BigQuery — Incident Analytics
Sample query:
```sql
SELECT incidentType, COUNT(*) AS count
FROM `project.safeher_dataset.incidents_raw_changelog`
GROUP BY incidentType
ORDER BY count DESC
```
- **Free tier:** 10 GB storage + 1 TB queries/month

### Cloud Functions — Backend & SOS
- `onIncidentCreated` — Firestore trigger; validates and sanitises new reports.
- `sendSOSAlert` — HTTP callable; dispatches location-based email alerts to emergency contacts.
- **Runtime:** Node.js (TypeScript/JavaScript)
- **Free tier:** 2 million invocations/month (Firebase Spark plan)

---

## SDG Alignment

| SDG | Contribution | Feature |
|---|---|---|
| **SDG 5 — Gender Equality** | Anonymous, stigma-free channel to report violence and access safety information | Anonymous reporting, SOS alert, safety heatmap |
| **SDG 16 — Peace, Justice & Strong Institutions** | Democratises legal knowledge; provides data-driven insights for law enforcement | Legal chatbot, BigQuery analytics |

---

## Getting Started

### Prerequisites
- Flutter SDK (≥ 3.x)
- Firebase project with Firestore, Auth, and Functions enabled
- Google Cloud project with Maps SDK, Dialogflow CX, and BigQuery APIs enabled

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/safeher.git
   cd safeher
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
   - Deploy Cloud Functions:
     ```bash
     cd functions
     npm install
     firebase deploy --only functions
     ```

4. **Enable BigQuery Streaming**
   - In Firebase Console → Extensions → install **Export Collections to BigQuery**.
   - Set the collection path to `/incidents`.

5. **Configure Dialogflow CX**
   - Create a CX agent in Google Cloud Console.
   - Add your agent credentials to the app configuration.

6. **Run the app**
   ```bash
   flutter run
   ```

---
