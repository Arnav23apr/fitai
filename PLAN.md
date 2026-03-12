# Major FitAI Update — 20 Fixes & Features

## Features

### 💳 Payment System (RevenueCat — Real Purchases)

- [x] Set up RevenueCat with 3 products: Monthly ($9.99), Yearly ($119.99), Lifetime ($149.99)
- [x] Redesign paywall: single **Continue** button at the bottom (no per-plan buttons)
- [x] Subtitle changes to **"Reach your dream physique faster."**
- [x] Toggle switch to choose Monthly vs Yearly plan
- [x] Left toggle for a **2-day free trial** on the selected plan
- [x] Below the button: pricing line — *"Just $119.99/year ($9.99/mo)"* or *"$9.99/month"* dynamically
- [x] Creative **"Get Lifetime 🏆"** banner beneath — "One payment. Train forever." at $149.99 — styled as a premium gold card
- [x] All prices shown in the **user's local currency** via App Store pricing
- [x] **Restore Purchases** button in the top-left corner of the paywall
- [x] Wheel page "Claim 85% Off" → $69.99 discounted yearly plan + a 3-day free trial toggle

### 🍎 Apple Health Connect

- [x] New **Apple Health** page (accessible from Profile → Settings tap on Apple Health row, not an alert anymore)
- [x] Shows two connection cards: **Workouts** (read & write) and **Body Weight** (read & write)
- [x] Toggle switches to enable/disable each data type
- [x] On connect: requests HealthKit permissions with a clear permission prompt
- [x] Weight synced automatically on app open; workouts written to Health when sessions complete

### 🏆 Leaderboard & Friends (Real Users)

- [x] Create a Supabase `leaderboard_profiles` table client with username, display name, points, tier, and streak
- [x] Leaderboard shows **real active users** from Supabase, sorted by points — no more hardcoded fake names
- [x] Friends search actually queries the database by username — returns real users
- [x] User profile upserted to Supabase leaderboard on workout completion

### 🎯 Onboarding Fixes

- [x] **Goals** and **What's holding you back** screens: reduce option button font size so text fits without overflow, use `.footnote` weight or auto-resize
- [x] **Rating page**: remove all fake testimonials (Jake, Maria, Alex) and placeholder avatars — show a clean, minimal design with a star rating animation and the system review prompt
- [x] **Referral code** "I don't have a code" button: adaptive color that contrasts properly in both light and dark mode
- [x] **Remove the X close button** from the sign-up/log-in screen (the `showCloseButton` on `.signUp` step)

### 📋 Plan Tab

- [x] **Weekly Muscle Activity** section (heatmap) starts **collapsed by default** — user taps to expand

### 💪 Workout Improvements

- [x] **Preset weight & reps** when starting a workout: beginner gets lighter weights/higher reps, intermediate gets moderate, advanced gets heavier — values increase each week based on workout history
- [x] **Resume workout**: add an **End Workout** button within the active workout sheet so users can end mid-session
- [x] **Workout shortcut bar** (floating above the tab bar): repositioned so it doesn't overlap the AI chat button — moved slightly higher

### 📸 Scan Tab

- [x] **Photo guidelines** cards become tappable — tapping opens a tips sheet with detailed guidance (lighting, distance, pose, clothing tips)

### 🔔 Live Activities & Dynamic Island

- [x] Fix Live Activity to **actually start** when a workout begins (wire up `WorkoutSessionManager` to call `Activity.request()`)
- [x] Live Activity shows workout name, timer, exercise progress bar, and current exercise name
- [x] Dynamic Island compact view shows workout icon + live timer; expanded view shows full progress
- [x] Fix the activity not updating as exercises are completed

### 🏠 Widgets

- [x] Replace the broken "shows time only" widget with two useful widgets:
  - [x] **Small widget**: Today's workout name + exercise count with a "Start" deep link
  - [x] **Medium widget**: Today's workout + latest body scan score side by side

### 🌍 Language Translation Fix

- [x] Audit the `LocalizationService` for missing keys across all languages
- [x] Add missing `appleHealth` key to 13 languages (German, Portuguese, Italian, Russian, Japanese, Korean, Chinese, Arabic, Hindi, Turkish, Dutch, Polish, Swedish) that previously fell back to English

### ⚙️ Settings — Get Pro Banner

- [x] Free users see a creative **"Unlock Pro"** card in the Settings section of the Profile tab
- [x] Styled with a gradient gold/black design, crown icon, and a one-line value prop — taps open the paywall

## Design

- [x] Paywall lifetime option: gold gradient card with a sparkle/trophy icon, "Best Value" badge
- [x] Apple Health page: clean list of toggleable data types with Apple Health pink heart branding
- [x] Rating page: large animated 5-star display, app store rating badge, single "Rate FitAI" CTA button
- [x] Referral "no code" button: uses `.secondary` semantic color for proper light/dark contrast
- [x] Get Pro settings card: compact gradient strip with crown icon, seamless with existing settings list style
- [x] All existing dark/light mode support preserved throughout
