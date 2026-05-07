# App Store Privacy & Compliance Checklist

The Privacy Policy and Terms of Service in this folder cover the **legal**
side. This checklist covers the **operational** side — items you must
configure in App Store Connect and inside the app itself before submitting.

> **Launch posture:** the App will be operated by an individual freelancer
> / sole trader (George) for the first launch period. Once a legal entity
> is incorporated, the operator name and contact details must be updated
> in: (1) the Privacy Policy and ToS files in this folder, (2) the
> hosted URLs, (3) App Store Connect → App Information, (4) the
> developer-account holder name on the Apple Developer Program (this
> is a separate process and may require Apple verification).

---

## 1. Privacy Policy URL (required for App Store submission)

App Review will reject any app that doesn't supply a publicly accessible
Privacy Policy URL.

**You must do:**
- Host `PRIVACY_POLICY.md` (rendered to HTML) at a stable public URL
  (e.g. `https://fitai.health/privacy` or a GitHub Pages URL).
- Paste that URL into App Store Connect → App Information → **Privacy
  Policy URL**.
- Wire the same URL into the app's UI:
  - The "Terms / Privacy" links in `PaywallView.swift` (currently empty
    `Button("Terms") {}` and `Button("Privacy") {}` — these are
    no-ops and App Review will catch this)
  - The "Terms / Privacy" labels in `SwipeUpSplashView.swift` (currently
    plain `Text` — make them tappable)
  - Any "About" / "Settings" screens

## 2. Privacy Nutrition Labels (required, separate from Privacy Policy)

App Store Connect → App Privacy section. You must declare every category
of data the app collects and what it's used for. **Apple cross-references
this with actual network traffic in iOS 17.2+** — mismatches between
what you declare and what the app actually transmits are the #1 reason
for delayed reviews. Be honest.

### Data linked to user (per Apple's terminology)

| Apple category | Specific data | Used for | Linked to user | Tracking |
|---|---|---|---|---|
| Contact info | Email | App functionality, account | Yes | **No** |
| Health & fitness | Body weight, height, age, training data, AI scan scores | App functionality | Yes | **No** |
| User content | Photos (body scans, battle photos, goal projection sources) | App functionality | Yes | **No** |
| Identifiers | User ID (Supabase UUID) | App functionality, Analytics | Yes | **No** |
| Usage data | Product interaction (anonymous events) | Analytics, Product personalization | Yes | **No** |
| Diagnostics | Crash data, performance | App functionality | Yes | **No** |
| Purchases | Purchase history | App functionality | Yes | **No** |

### Critical settings under "Photos"

Under the **Photos** category specifically:
- ✅ **Linked to user**: Yes
- ❌ **Used for tracking**: leave **UNCHECKED**
- ✅ **Purposes**: ONLY tick **App Functionality**
- ❌ **Do NOT tick**: "Other Purposes", "Third-Party Advertising",
  "Developer's Advertising or Marketing" — any of these triggers a
  manual reviewer look and can stall release by 1–2 weeks.

### "Data Used to Track You" section

Photos must NOT appear here. Tracking under Apple's definition means
linking the data to third-party data for advertising. We don't do this.
Set the entire app to "Data is Not Used to Track You."

### Data NOT collected (be explicit)
- Browsing history, location (we strip EXIF GPS before upload), contacts,
  financial info, search history.

### Domains contacted disclosure

iOS 17.2+ requires you to declare third-party domains the app contacts.
Add to `Info.plist` `NSPrivacyTrackingDomains` (array, can be empty
since we don't track) and ensure your app's outbound connections to
the following are disclosed in the privacy policy:
- `*.supabase.co` / your Supabase project URL
- `generativelanguage.googleapis.com` (Google Gemini)
- `api.revenuecat.com`

If the App Privacy Report (iOS Settings → Privacy → App Privacy Report)
shows a connection that isn't in the Privacy Policy, fix the policy
**before** users notice.

## 3. Privacy Manifest (`PrivacyInfo.xcprivacy`) — iOS 17+ requirement

Apple requires a privacy manifest for the app and any third-party SDKs
that access certain APIs:

- Add a `PrivacyInfo.xcprivacy` file to the Xcode project (root of main
  target) declaring:
  - `NSPrivacyTracking`: `false`
  - `NSPrivacyTrackingDomains`: `[]`
  - `NSPrivacyAccessedAPITypes`: declare any "Required Reason API"
    you use (e.g. `UserDefaults` access requires reason code `CA92.1`)
- Verify each third-party SDK in your project ships its own
  `PrivacyInfo.xcprivacy`:
  - RevenueCat (already provides one as of v5.x ✓)
  - Supabase Swift SDK
  - MuscleMap

If a third-party SDK doesn't provide one, App Store submission will warn
about it (currently a warning; will become a hard block).

## 4. In-app Info.plist usage strings (verify before submission)

Generic strings get rejected under 5.1.1 in 2025. Each must name the
purpose AND retention.

Required strings:
- `NSCameraUsageDescription`:
  > **"FitAI uses your camera to scan your physique. Photos used purely
  > for scoring are not stored. Photos used for your 'Future You' image
  > are deleted after 30 days."**
- `NSPhotoLibraryUsageDescription`:
  > **"FitAI uses your photo library to pick existing physique photos
  > for analysis or 1v1 battles. Battle photos are deleted after 7 days."**
- `NSHealthShareUsageDescription` (existing): leave as-is, already specific
- `NSHealthUpdateUsageDescription` (existing): leave as-is

Do NOT add (we don't use these):
- `NSUserTrackingUsageDescription` (no ATT tracking)
- `NSLocationWhenInUseUsageDescription` (we strip EXIF GPS, don't ask
  for location)
- `NSContactsUsageDescription`
- `NSMicrophoneUsageDescription`

## 5. Subscription metadata in App Store Connect

Required disclosures **on the paywall screen** (Apple checks this):
- Title of the subscription
- Length of the subscription period
- Price per period
- Functional description of what the subscription unlocks
- Link to the Privacy Policy
- Link to the Terms of Service / EULA
- Statement that subscription auto-renews unless cancelled 24h before
  renewal
- Statement that payment is charged to Apple ID

The current `PaywallView.swift` shows price + auto-renew text in the
caption. You should also wire the Terms / Privacy buttons to actual links
(see #1 above) — App Review will check.

## 6. Account deletion (required since iOS 16.4)

Apple requires apps that support account creation to **also** support
in-app account deletion. The Privacy Policy promises this in Section 7.

**Implementation status:** TODO. There is currently no "Delete Account"
button in the Profile/Settings UI. Add one before submission. The
deletion handler should:
1. Call Supabase to delete the user's profile, scans, workouts,
   referral attributions, and auth user.
2. Clear local UserDefaults, Keychain, and the encrypted scan photo store.
3. Sign out and return to the splash.

This is a hard App Review requirement.

## 7. Health & Fitness disclaimer placement

Apple specifically reviews fitness apps that make body-composition or
health claims. Recommended:
- Show the medical disclaimer (Section 11 of ToS) on first launch of
  the scan flow.
- Repeat a short version in any AI-generated meal plan or workout view.
- Add the full disclaimer to `Settings → About / Disclaimers`.

## 8. EU Digital Services Act (DSA) — required for EU launch

If the App is available in the EU, App Store Connect will require you to
declare **Trader status**. Even as a freelancer / sole trader selling a
paid subscription, you ARE a trader under EU law. You must:

- In App Store Connect → App Information → set **Trader Status**: **Trader**.
- Provide the operator's verifiable contact info (full legal name, address,
  phone, email). For a sole trader this is George's personal info — Apple
  will display it publicly to EU users on the App Store listing.
- If operating from the EU, ensure invoicing / VAT compliance with local
  rules. **Apple is the merchant of record for App Store sales**, so Apple
  collects and remits VAT for B2C subscriptions to EU users automatically.
  George still owes income tax in his country of residence on the payouts
  Apple sends him.

## 9. App Store Connect Account Holder

The Apple Developer Program account holder name is what appears as the
"Seller" on the App Store. For the freelancer launch this should be:
- **Account type:** Individual (not Organization)
- **Name:** {{OPERATOR_NAME}} (George's full legal name)
- **Address / phone / email:** George's

When you incorporate the entity, you'll either:
- (a) Migrate the developer account from Individual → Organization (Apple
  requires verification of the entity, takes ~1–2 weeks), or
- (b) Open a fresh Organization account and transfer the App. Apple's
  app-transfer flow exists but is one-way and slow.

Plan ahead — option (a) is usually cleaner.

## 10. Tax / banking setup (operational, not legal)

Before payouts can flow:
- App Store Connect → Agreements, Tax, and Banking → complete the
  **Paid Apps Agreement**.
- W-8BEN form (for non-US individuals) — declares George's tax residency
  to avoid US withholding on the US share of revenue.
- VAT info (EU sole traders) — if registered for VAT, supply VAT ID.
  Apple still acts as merchant of record; the VAT ID is for invoicing.
- Bank account in George's name for payouts.

---

## What to do with these documents

1. **Fill the placeholders** (see "What I need from your side" below).
2. **Have a lawyer review** the filled documents. Both files are
   templates tailored to FitAI's actual data practices, not legal advice.
3. **Host the rendered HTML versions** at stable URLs.
4. **Wire those URLs into the app** at the spots listed in #1.
5. **Configure App Store Connect** with the URLs and the privacy labels.
6. **When you incorporate**, reissue both documents with the new entity,
   notify users in-app, and update the App Store Connect operator info.

---

## What I need from your side

To finalize the documents, replace these placeholders consistently across
both files:

| Placeholder | What it is | Example |
|---|---|---|
| `{{OPERATOR_NAME}}` | George's full legal name as it appears on official ID / tax records | "George {{LASTNAME}}" |
| `{{OPERATOR_ADDRESS}}` | George's registered place of business — usually his home address for sole traders | "Strada Exemplu 1, 010101 Bucharest, Romania" |
| `{{COUNTRY}}` | George's country of tax residency | "Romania" |
| `{{TAX_ID_LINE}}` | Optional. Leave empty (`""`) if George operates as a pure individual; otherwise put `" (registered as PFA, fiscal code XXXXXXXX)"` or similar — only relevant if he registers as a sole-trader entity (PFA in Romania, freelance VAT ID in EU, etc.) | `""` or `" (PFA, CUI 12345678)"` |
| `{{PRIVACY_CONTACT_EMAIL}}` | Email for privacy/data requests | `team@fitai.health` |
| `{{LEGAL_CONTACT_EMAIL}}` | Email for legal/ToS questions (can be the same) | `team@fitai.health` |
| `{{SUPABASE_REGION}}` | The region your Supabase project is hosted in | "EU (Frankfurt)" or "US East" |
| `{{GOVERNING_LAW_JURISDICTION}}` | Country whose laws govern the agreement — normally where George is tax resident | "Romania" |
| `{{COURT_JURISDICTION}}` | Where disputes are litigated | "the courts of Bucharest, Romania" |
| `{{EFFECTIVE_DATE}}` | Date the policy takes effect | "1 May 2026" |
| `{{LAST_UPDATED_DATE}}` | Date you last edited it | same as effective date for v1 |

Other things I need:
- **A public URL** (or two) where you'll host the rendered Privacy Policy
  and ToS. Cheapest option: GitHub Pages on a repo named `fitai-legal`
  (free, fast, supports markdown rendering). Once you have a domain,
  redirect `/privacy` and `/terms` there.
- **George's full legal name** as it appears on his ID, exactly. Apple
  will cross-check this against the developer account.
- **George's tax residency country.** Affects governing law, VAT, W-8BEN.
- **Whether he's registered as a sole trader / freelancer entity** (PFA
  in Romania, equivalent in other EU countries) or operating as a pure
  individual. Both work; it just changes one line of the docs.
- **Your Supabase project region** (visible in the Supabase dashboard).
- **Confirmation of age limit.** I've assumed 13+ (US COPPA) and 16+ (EU
  GDPR). If you want to set the floor higher (16+ globally for
  simplicity), say so and I'll update both files.

Once you give me those values + the public URLs, I can:
- Run a find-and-replace pass and produce the final filled documents.
- Wire the in-app Terms/Privacy buttons to the URLs (`PaywallView.swift`
  and `SwipeUpSplashView.swift`).
- Build the in-app account-deletion flow (Apple App Review hard
  requirement — currently TODO).
- Add the medical-disclaimer modal on first scan.
- When the SRL is incorporated later, do another find-and-replace pass
  to swap George's name for the entity name and update the in-app
  notification banner.
