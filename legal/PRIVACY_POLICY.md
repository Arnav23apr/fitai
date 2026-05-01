# Privacy Policy

**Effective date:** {{EFFECTIVE_DATE}}
**Last updated:** {{LAST_UPDATED_DATE}}

> ⚠️ **Important:** This document is a starting template tailored to FitAI's
> actual data practices. It is **not legal advice**. Have a qualified attorney
> in your jurisdiction review it before publishing. Apple App Review will
> reject your submission if the policy URL is missing or the policy is
> materially incomplete.
>
> **Current operator status:** This version is written for the launch period
> during which the App is operated by an individual freelancer / sole trader.
> Once the planned legal entity is incorporated, this Policy must be reissued
> naming the entity as the data controller, and users must be notified of the
> change in-app and at the URL where this Policy is hosted.

This Privacy Policy describes how **{{OPERATOR_NAME}}** ("FitAI", "we",
"us") collects, uses, and shares your personal information when you use the
FitAI iOS application (the "App") and related services.

---

## 1. Who we are

FitAI is operated by **{{OPERATOR_NAME}}**, an individual freelancer /
sole trader trading under the brand "FitAI", with a registered place of
business at {{OPERATOR_ADDRESS}}, {{COUNTRY}}{{TAX_ID_LINE}}.

For privacy questions or to exercise your rights, contact us at
**{{PRIVACY_CONTACT_EMAIL}}**.

If you are in the European Economic Area, {{OPERATOR_NAME}} (acting as a
natural person under their own name) is the **data controller** for your
personal data. We will update this section if and when the operating entity
changes (e.g. incorporation of a limited company).

---

## 2. What we collect

We only collect data needed to operate the App. The categories below reflect
what FitAI actually collects today.

### 2.1 Account information
- Email address (for sign-in via Supabase Auth)
- Display name and username
- Account creation timestamp
- Authentication tokens (managed by Supabase)

### 2.2 Profile and onboarding answers
Information you provide during onboarding or in the profile screen, including:
- Gender
- Date of birth (used to derive age)
- Height and weight
- Primary fitness goal, secondary goals, training experience, training
  location, workouts per week, self-rated training confidence, perceived
  obstacles ("holding back")
- Selected app language
- Optional avatar and bio

### 2.3 Body scan photos and analysis results
- Photos you take or upload for AI physique analysis ("scans")
- The AI-generated assessment of each scan, including overall score, strong
  points, weak points, and per-muscle-group scores
- Scan history (date, score, photo reference)

### 2.4 Workout and activity data
- Workouts you log (exercises, sets, reps, weights, duration)
- Workout streaks, total workouts, points, tier
- Personal records (PRs)

### 2.5 Subscription and purchase data
- Subscription status, plan tier, premium flag
- Purchase receipts and renewal events (handled by Apple and RevenueCat;
  we do not see or store payment card details)

### 2.6 Referral data
- Your unique outbound referral code
- Codes you entered during onboarding (`referredByCode`)
- Attribution records connecting referrer to referred user
- Count of friends who joined using your code

### 2.7 Device and technical data
- Device model, iOS version, app version
- Crash logs and diagnostic data (only if you opt in via iOS Settings)
- Anonymous in-app analytics events (e.g., screen views, feature usage)

### 2.8 Apple Health data (optional, if you grant permission)
If you connect Apple Health, we may **read** body weight, workouts, heart rate,
and active energy from Health, and **write** your completed workouts and body
weight back to Health. Health data is processed on your device and is not
transmitted to our servers without your explicit action.

### 2.9 What we do not collect
- Payment card numbers (Apple handles this)
- Precise location
- Browser cookies (the App is native iOS; this Policy does not apply to a
  website unless one is added later)
- Contacts, microphone audio, or camera footage outside of explicit photo
  capture for scans

---

## 3. How we use your data

We use the data above for the following purposes:

| Purpose | Categories used | Legal basis (GDPR) |
|---|---|---|
| Provide AI scan analysis | Photos, profile data | Contract |
| Generate personalized workout plans, meal plans, coach responses | Profile data, scan results, workout logs | Contract |
| Sync your data across reinstalls and devices | All account data | Contract |
| Process subscriptions and manage entitlements | Account, subscription data | Contract |
| Operate the referral program | Referral codes, attribution data | Contract / Legitimate interests |
| Detect abuse, fraud, and policy violations | All categories | Legitimate interests |
| Improve product quality (aggregate analytics) | Anonymous usage events | Legitimate interests |
| Send service announcements (rare) | Email | Legitimate interests |
| Comply with legal obligations | All categories as needed | Legal obligation |

We **do not** sell your personal data, and we **do not** use it to train
foundation AI models that benefit third parties.

---

## 4. How AI processing works

When you submit a body scan photo for analysis, the photo and a context block
derived from your profile (gender, age, height/weight, training goals, prior
weak points) are sent to our AI provider, **Google (Gemini API)**, for
inference. Google processes the request, returns the assessment, and we store
the result on our backend.

- We use the Gemini API in **non-training** mode: per Google's API terms, your
  prompts and photos are not used to train Google's foundation models.
- Photos are sent over TLS and are not retained by Google beyond the
  short windows necessary for abuse detection per Google's API terms.
- We do not share your photos with any other AI vendor.

The AI analysis is informational and is **not a medical diagnosis**. See
Section 11 (Health and Medical Disclaimer) of our Terms of Service.

---

## 5. Third parties we share data with

We share the minimum data necessary with the following service providers, all
of whom are bound by data-processing agreements:

| Provider | Purpose | Data shared |
|---|---|---|
| Supabase (PostgreSQL hosting) | User database, auth, storage | All account data |
| Google (Gemini API) | AI scan analysis, plan generation, coach chat | Photos and profile context per request; not retained by Google for training |
| Apple (App Store, StoreKit) | Sign-in with Apple, payments, push notifications | Apple-managed identifiers |
| RevenueCat | Subscription state management | Apple receipt data, anonymous user ID |
| Apple HealthKit | (Optional) sync workouts and weight | Stays on your device by default |

We do not share data with advertisers or data brokers.

If we ever change AI providers, payment processors, or backend hosts, we will
update this list and notify users in-app.

---

## 6. International data transfers

Our backend (Supabase) is hosted in **{{SUPABASE_REGION}}**. AI requests are
processed by Google in regions disclosed by Google. If you are in the EEA, UK,
or Switzerland, your data may be transferred to the United States or other
regions. Where required, we rely on the **European Commission's Standard
Contractual Clauses** or equivalent safeguards.

---

## 7. Data retention

| Data | Retention period |
|---|---|
| Account profile | Until you delete your account |
| Scan photos and history | Until you delete a scan or delete your account |
| Workout logs | Until you delete your account |
| Subscription receipts | 7 years (tax / accounting requirement) |
| Referral attribution rows | Until either user deletes their account |
| Crash and diagnostic logs | 90 days |
| Backups | Up to 30 days after primary deletion |

You can delete your account at any time from **Profile → Settings → Delete
Account**, which permanently removes your profile, scans, workouts, and
referral attributions from our backend within 30 days.

---

## 8. Your rights

Depending on where you live, you have some or all of the following rights:

- **Access** — request a copy of the personal data we hold about you
- **Rectification** — correct inaccurate data
- **Erasure ("right to be forgotten")** — delete your data
- **Restriction / objection** — limit how we process your data
- **Portability** — receive your data in a structured, machine-readable format
- **Withdraw consent** — where processing is based on consent
- **Lodge a complaint** with your local data protection authority

To exercise any right, email **{{PRIVACY_CONTACT_EMAIL}}**. We respond within
30 days (60 in complex cases).

### California (CCPA / CPRA)
California residents have the right to know what personal information we
collect, request deletion, correct inaccurate information, and opt out of any
sale or sharing of personal data. **We do not sell or share personal data as
those terms are defined under the CCPA.**

### Children
FitAI is **not directed to children under 13** (or under 16 in the EU). We do
not knowingly collect data from children under those thresholds. If you
believe a child has created an account, contact us and we will delete it.

---

## 9. Security

We protect your data using:
- TLS 1.2+ in transit for all client-server traffic
- Encryption at rest for the database (managed by Supabase)
- Encryption at rest for body photos stored locally on your device
  (`completeFileProtection`)
- Row-level security (RLS) policies on user-owned tables
- Limited employee access on a need-to-know basis

No system is perfectly secure. If we discover a breach affecting your personal
data, we will notify affected users and applicable authorities as required by
law.

---

## 10. Push notifications

If you grant notification permission, we send service-related notifications
(workout reminders, streak nudges, friend referrals). You can disable any
category in **Settings → Notifications → FitAI** at any time.

---

## 11. Changes to this Policy

We may update this Privacy Policy from time to time. If changes are material,
we will notify you in-app and/or by email at least 14 days before the new
version takes effect. The "Last updated" date at the top reflects the most
recent revision.

---

## 12. Contact

For privacy questions, requests, or complaints, contact:

**{{OPERATOR_NAME}}**
Trading as "FitAI"
{{OPERATOR_ADDRESS}}
{{COUNTRY}}
Email: **{{PRIVACY_CONTACT_EMAIL}}**

---

*Document version: 1.0 (sole trader / freelancer launch)*
