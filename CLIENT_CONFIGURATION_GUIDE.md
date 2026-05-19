# Cadeli iOS — Client Configuration Guide

This guide lists every external dashboard configuration that needs to be completed on **your accounts** before the iOS app can be fully functional and submitted to the App Store.

> **Why this is on your side:** these steps all happen inside accounts you own (Apple Developer, Google Cloud, Stripe, Firebase, App Store Connect). The developer cannot do them without your account access, and your business identity / payment methods need to be tied to them anyway.

When you finish each section, send the requested values back to the developer so the code can be wired up.

---

## ⚠️ Important — values you MUST send back for code matching

The app has several identifiers and keys that are currently hardcoded or referenced in the source code. After you configure everything on your side, the developer needs to **compare your live values against what's in the code** to catch any mismatch. A single character off in any of these and the corresponding feature breaks.

Please send the developer the **exact, copy-pasted** values for the following so they can be verified line-by-line against the source:

1. **Apple Pay merchant identifier** — code currently uses `merchant.com.cadeli`. Confirm this is the exact identifier you created in Apple Developer and registered with Stripe.
2. **iOS bundle identifier** — must match across: Apple App ID, provisioning profile, Xcode project, Firebase iOS app entry, Google Maps API key restriction. The developer will verify all four match.
3. **Stripe live publishable key** (`pk_live_...`) — replaces the test key currently in the code.
4. **Stripe live secret key** (`sk_live_...`) — used by Cloud Functions. **Send via password manager only.**
5. **Stripe webhook signing secret** — for verifying webhook calls in Cloud Functions.
6. **Google Maps iOS API key** — the new restricted key replaces the currently hardcoded Places key.
7. **Firebase project ID** — should already match `firebase_options.dart`, but confirm to be safe.
8. **Apple Team ID** — used in signing and Apple Pay configuration.
9. **Sign in with Apple Services ID** — created during Firebase Apple provider setup.

The developer will not "trust" the code — they will diff your values against the source on every relevant line. If anything mismatches, that's almost certainly part of the current breakage.

> **Why this matters:** the current app has at least one example of this exact problem — a hardcoded Places API key in [lib/screens/pick_location_page.dart:16](lib/screens/pick_location_page.dart) that is exposed in the binary AND in GitHub history. Without matching the live values against the code, more issues like this stay hidden.

---

## Estimated time

| Section | Time | Skill |
|---|---|---|
| 1. Google Cloud (Maps) | 30–45 min | Admin |
| 2. Firebase Console | 30 min | Admin |
| 3. Apple Developer Portal | 45 min | Admin |
| 4. Stripe Dashboard | 30–60 min | Admin + business docs |
| 5. App Store Connect | 60–90 min | Admin + marketing info |
| **Total** | **~4 hours** | |

---

## 1. Google Cloud Console — Maps & Places APIs

The app uses Google Maps for delivery tracking and Google Places for address autocomplete. These require a separate Google Cloud project with billing enabled — they are NOT part of Firebase.

> **"Can the developer do this for me?"** — Partially. The developer can enable the APIs and create the API key **if you grant them Owner access** to the GCP project. But the **billing setup must be done by you** because:
> - The credit card / payment method must be tied to your business identity for legal and accounting purposes.
> - Google Cloud will not let a third party add their own card to your project.
> - If the developer adds their card and forgets to remove it, your usage costs end up on their bill (or, more likely, the project gets suspended when they cancel).
>
> **Recommended approach:** you handle billing yourself (10 minutes — just adding a card). Then either (a) continue with the API enablement / key creation yourself, or (b) add the developer as an Owner on the GCP project and they finish it. Both work. Option (b) is faster if the console UI is unfamiliar.

**Where to go:** https://console.cloud.google.com/

### Steps

1. **Sign in with the same Google account** that owns the Firebase project.
2. **Select the project** from the top dropdown — use the same one as Firebase (Firebase creates a GCP project automatically).
3. **Enable billing**
   - Left menu → **Billing**
   - Link a billing account (credit card or invoiced)
   - Without billing, Maps and Places APIs return errors on every call.
4. **Enable the required APIs**
   - Left menu → **APIs & Services → Library**
   - Search and enable each of the following one at a time:
     - ✅ **Maps SDK for iOS**
     - ✅ **Places API**
     - ✅ **Geocoding API**
     - ✅ **Directions API** (only if the app does turn-by-turn or route drawing)
5. **Create a restricted API key**
   - Left menu → **APIs & Services → Credentials**
   - Click **Create credentials → API key**
   - Click **Edit API key** on the new key
   - **Application restrictions:** select **iOS apps** → click **Add an item** → paste the iOS bundle identifier (the developer will give you this — typically something like `gr.anastasios.cadeli`)
   - **API restrictions:** select **Restrict key** → tick all four APIs you enabled above
   - Click **Save**
6. **Set a budget alert** (optional but strongly recommended)
   - Left menu → **Billing → Budgets & alerts**
   - Set a monthly cap (e.g. €50) and alerts at 50%/90%/100% — protects against runaway costs from a leaked or misconfigured key.

### Send back to developer

- 🔑 The new restricted **iOS Maps API key** (string starting with `AIza...`)
- ✅ Confirmation that billing is enabled

---

## 2. Firebase Console — Push Notifications, Auth Providers, Functions

You already configured Firebase, but two critical iOS-specific steps are commonly missed.

**Where to go:** https://console.firebase.google.com/

### 2a. Upload the APNs Authentication Key

Without this, push notifications **do not work on iOS at all**, regardless of what the app code does.

1. **Generate the APNs key in Apple Developer** (do this first — see Section 3 for context)
   - https://developer.apple.com/account/resources/authkeys/list
   - Click the **+** to create a new key
   - Name it `Cadeli APNs Key` (or similar)
   - Tick **Apple Push Notifications service (APNs)**
   - Click **Continue → Register**
   - **Download the `.p8` file** — you can only download it once. Save it somewhere safe.
   - Note the **Key ID** (10 characters, shown on the same screen)
   - Note your **Team ID** (top-right corner of Apple Developer site)
2. **Upload to Firebase**
   - Firebase Console → click the gear icon → **Project settings**
   - **Cloud Messaging** tab
   - Scroll to **Apple app configuration** → your iOS app
   - Under **APNs Authentication Key**, click **Upload**
   - Upload the `.p8` file, paste the **Key ID** and **Team ID**
   - Click **Upload**

### 2b. Enable Sign-in Providers

The app uses Google Sign-In, and Apple **requires** Sign in with Apple if you offer any other third-party login. Without Sign in with Apple, the App Store will reject your submission (guideline 4.8).

1. Firebase Console → **Authentication → Sign-in method**
2. Enable **Google** (should already be done — verify)
3. Enable **Apple**
   - Click **Apple → Enable**
   - You may need to provide your **Apple Team ID** and a **Services ID** (the Firebase wizard guides you)

### 2c. Upgrade to Blaze plan (if not already) and deploy Cloud Functions

The repo contains backend code in [functions/](functions/) that needs to be deployed for parts of the app (Stripe webhooks, server-side logic, secure API key proxying) to work.

1. Firebase Console → **Upgrade plan** → choose **Blaze (Pay as you go)**
   - Blaze is required to deploy Cloud Functions and to make outbound network calls (e.g. Stripe, Google Maps)
   - The free tier on Blaze is generous — for an app this size, expect <€5/month unless you have very high traffic
2. The developer will deploy the functions once Blaze is active. **You only need to upgrade — they handle the deploy.**

### Send back to developer

- ✅ Confirmation that the APNs key is uploaded
- ✅ Confirmation that Sign in with Apple is enabled in Firebase
- ✅ Confirmation that the Firebase project is on the Blaze plan

---

## 3. Apple Developer Portal — Capabilities and Merchant ID

You have a signed iOS app already (from the first build engagement), but the **App ID needs additional capabilities enabled**, and the provisioning profile must be regenerated after each capability change.

**Where to go:** https://developer.apple.com/account/resources/identifiers/list

### 3a. Enable capabilities on the App ID

1. Open the App ID for `gr.anastasios.cadeli` (or whatever your bundle identifier is)
2. Tick the following capabilities:
   - ✅ **Push Notifications**
   - ✅ **Sign In with Apple**
   - ✅ **Apple Pay Payment Processing**
   - ✅ **Associated Domains** (only if you plan to support deep links / Universal Links — skip if not sure)
3. Click **Save**

### 3b. Create the Apple Pay Merchant ID

The app's code references a merchant ID called `merchant.com.cadeli`. It must exist in your Apple Developer account.

1. Sidebar → **Identifiers**
2. Top dropdown → change from **App IDs** to **Merchant IDs**
3. Click the **+** button
4. Description: `Cadeli Apple Pay`
5. Identifier: `merchant.com.cadeli` (must match exactly — case-sensitive)
6. Click **Continue → Register**

### 3c. Link the Merchant ID to the App ID

1. Go back to **Identifiers → App IDs**
2. Open your App ID
3. Edit **Apple Pay Payment Processing** capability
4. Select the merchant ID you just created
5. Save

### 3d. Regenerate the Provisioning Profile

**This is mandatory after any capability change.** The old profile does not include the new entitlements and signing will fail.

1. Sidebar → **Profiles**
2. Find the App Store distribution profile created during the first build engagement
3. Click **Edit**
4. Re-tick the certificate and confirm the App ID is still selected
5. Click **Save** → **Download**
6. Send the new `.mobileprovision` file to the developer (they will update the GitHub Actions secret `IOS_PROVISIONING_PROFILE_BASE64`)

### Send back to developer

- 📎 The new `.mobileprovision` file (or its base64-encoded version per the existing build secrets guide)
- ✅ Confirmation that `merchant.com.cadeli` exists and is linked to the App ID

---

## 4. Stripe Dashboard — Apple Pay & Live Mode

**Where to go:** https://dashboard.stripe.com/

### 4a. Switch to Live Mode (if not done)

1. Top-right corner: toggle from **Test mode** to **Live mode**
2. If your account is not yet verified for live payments, you'll be prompted to complete **business verification** — this requires:
   - Business registration documents
   - Bank account details
   - Owner ID
   - VAT/tax info
3. This step **cannot be done by the developer** — Stripe legally requires the account owner.

### 4b. Register the Apple Pay Merchant ID with Stripe

1. Dashboard → **Settings** (gear icon) → **Payments → Payment methods**
2. Find **Apple Pay** → click **Configure** (or **Add merchant ID**)
3. Click **Add new merchant ID** → paste `merchant.com.cadeli`
4. Stripe will provide a **Certificate Signing Request (CSR)** to download
5. Go to Apple Developer:
   - **Identifiers → Merchant IDs → `merchant.com.cadeli`**
   - **Apple Pay Payment Processing Certificate → Create Certificate**
   - Upload the CSR Stripe just gave you
   - Download the resulting `.cer` file
6. Back in Stripe: upload the `.cer` file
7. Stripe will mark Apple Pay as **Active** for that merchant ID

### 4c. Get your live publishable key

1. Dashboard → **Developers → API keys** (while in Live mode)
2. Copy the **Publishable key** (starts with `pk_live_...`)
3. Copy the **Secret key** (starts with `sk_live_...`) — **do not share this in chat or email; share via a password manager or secret-sharing tool**

### 4d. Configure webhooks (developer will help with the endpoint URL)

1. Once the Cloud Functions are deployed (Section 2c), the developer will give you a webhook URL
2. Dashboard → **Developers → Webhooks → Add endpoint**
3. Paste the URL, select relevant events (typically `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`)
4. After creating, copy the **Signing secret** and send it to the developer

### Send back to developer

- 🔑 **Live publishable key** (`pk_live_...`) — safe to share
- 🔐 **Live secret key** (`sk_live_...`) — share via a password manager only, never in chat/email
- ✅ Confirmation that `merchant.com.cadeli` is active in Stripe
- 🔐 **Webhook signing secret** (once webhooks are set up) — also via password manager

---

## 5. App Store Connect — Submission Requirements

These are required by Apple for submission. None of them affect whether the app *runs*, but the app cannot be submitted without them.

**Where to go:** https://appstoreconnect.apple.com/

### 5a. App Privacy declarations

1. **My Apps → Cadeli → App Privacy**
2. Click **Get Started** if not already filled in
3. Declare every data type collected. Based on what the app uses, expect to declare:
   - **Contact Info:** Email address, Name, Phone Number
   - **Location:** Precise location, Coarse location
   - **Identifiers:** User ID, Device ID
   - **Usage Data:** Product interaction (Firebase Analytics)
   - **Diagnostics:** Crash data, Performance data (Firebase Crashlytics)
   - **Financial Info:** Payment info (Stripe)
4. For each, declare purpose (App Functionality, Analytics, etc.) and whether it's linked to user identity
5. **Apple holds you legally accountable for accuracy here.** If unsure, the developer can confirm what is actually collected by the code.

### 5b. App Information

1. **App Information** tab → fill in:
   - Subtitle, category (likely Food & Drink), content rights
   - Privacy Policy URL — must be a publicly accessible URL hosting your privacy policy
2. **Pricing and Availability** → set price (Free) and select territories

### 5c. App Review Information

The Apple reviewer needs to log in and use the app to approve it.

1. **App Information → App Review Information**
2. Provide:
   - **Demo account credentials:** a working test login (email + password) for a customer account with sample data
   - If the app has different roles (customer / driver / admin), provide one of each
   - **Contact info:** name, phone, email — Apple may call if review fails
   - **Notes:** brief explanation of what the reviewer should test

### 5d. Age rating & content descriptors

1. **App Information → Age Rating → Edit**
2. Walk through the questionnaire (likely all "None" for a delivery app → 4+ rating)

### 5e. Export compliance

1. **TestFlight → Build → Export Compliance**
2. For an app that only uses HTTPS / standard iOS encryption: answer **Yes, uses encryption** then **Yes, exempt** (standard exemption for HTTPS-only apps)

### 5f. Pricing & tax forms

1. **Agreements, Tax, and Banking** (top menu, only visible to account holder)
2. Sign the Paid Apps Agreement if accepting payments (even though Stripe handles the money, this is required for apps that aren't free)
3. Fill in tax forms for your country

### Send back to developer

- ✅ Confirmation that App Privacy is filled in
- 🔑 Demo account credentials for App Review (so the developer can also use them to verify the build before submission)

---

## What the developer still has to do (for context — not your work)

After you finish the above, these remain on the developer's side:

- Wire the new Google Maps API key into the iOS native code
- Switch the Stripe key in the app from test to live
- Remove the hardcoded Places API key from the source and route it through Cloud Functions
- Implement Sign in with Apple in the auth flow (it's only enabled in Firebase — the app still needs to render the button and handle the callback)
- Add `NSUserTrackingUsageDescription` and other missing permission strings to `Info.plist`
- Deploy the Cloud Functions to the Blaze project
- Configure the Stripe webhook endpoint in the deployed functions
- Run the app on a real device and fix runtime crashes that weren't visible in static analysis
- Rebuild and resubmit

---

## Checklist to send back

When you've finished, please send the developer this filled-in summary:

```
[ ] Google Cloud billing enabled
[ ] Maps SDK for iOS / Places API / Geocoding API enabled
[ ] iOS-restricted Maps API key: ________________________
[ ] Firebase APNs key uploaded
[ ] Firebase Auth: Google enabled
[ ] Firebase Auth: Apple enabled
[ ] Firebase Blaze plan active
[ ] Apple Developer: Push Notifications capability enabled
[ ] Apple Developer: Sign In with Apple capability enabled
[ ] Apple Developer: Apple Pay capability enabled
[ ] Apple Developer: merchant.com.cadeli created and linked to App ID
[ ] New provisioning profile generated and sent: ________________
[ ] Stripe account verified for live payments
[ ] Stripe Apple Pay configured for merchant.com.cadeli
[ ] Stripe live publishable key: pk_live_________________
[ ] Stripe live secret key sent via: _____________ (password manager link)
[ ] App Store Connect: Privacy declarations complete
[ ] App Store Connect: App Review demo account: user=__________ pass=__________
[ ] App Store Connect: Export compliance answered
[ ] App Store Connect: Tax/banking forms signed
```

Once we have these, the developer will have a clear picture of what's left as actual code work versus configuration that's now in place.
