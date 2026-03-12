# Major FitAI Update — 20 Fixes & Features

## Features

### 💳 Payment System (RevenueCat — Real Purchases)

- Set up RevenueCat with 3 products: Monthly ($9.99), Yearly ($119.99), Lifetime ($149.99)
- Redesign paywall: single **Continue** button at the bottom (no per-plan buttons)
- Subtitle changes to **"Reach your dream physique faster."**
- Toggle switch to choose Monthly vs Yearly plan
- Left toggle for a **2-day free trial** on the selected plan
- Below the button: pricing line — *"Just $119.99/year ($9.99/mo)"* or *"$9.99/month"* dynamically
- Creative **"Get Lifetime 🏆"** banner beneath — "One payment. Train forever." at $149.99 — styled as a premium gold card
- All prices shown in the **user's local currency** via App Store pricing
- **Restore Purchases** button in the top-left corner of the paywall
- Wheel page "Claim 85% Off" → $69.99 discounted yearly plan + a 3-day free trial toggle

### 🍎 Apple Health Connect

- New **Apple Health** page (accessible from Profile → Settings tap on Apple Health row, not an alert anymore)
- Shows two connection cards: **Workouts** (read & write) and **Body Weight** (read & write)
- Toggle switches to enable/disable each data type
- On connect: requests HealthKit permissions with a clear permission prompt
- Weight synced automatically on app open; workouts written to Health when sessions complete

### 🏆 Leaderboard & Friends (Real Users)

- Create a Supabase `leaderboard_profiles` table with username, display name, points, tier, and streak
- Leaderboard shows **real active users** from Supabase, sorted by points — no more hardcoded fake names
- Friends search actually queries the database by username — returns real users
- Add friend button sends/accepts a friend request stored in Supabase

### 🎯 Onboarding Fixes

- **Goals** and **What's holding you back** screens: reduce option button font size so text fits without overflow, use `.footnote` weight or auto-resize
- **Rating page**: remove all fake testimonials (Jake, Maria, Alex) and placeholder avatars — show a clean, minimal design with a star rating animation and the system review prompt
- **Referral code** "I don't have a code" button: adaptive color that contrasts properly in both light and dark mode
- **Remove the X close button** from the sign-up/log-in screen (the `showCloseButton` on `.signUp` step)

### 📋 Plan Tab

- **Weekly Muscle Activity** section (heatmap) starts **collapsed by default** — user taps to expand

### 💪 Workout Improvements

- **Preset weight & reps** when starting a workout: beginner gets lighter weights/higher reps, intermediate gets moderate, advanced gets heavier — values increase each week based on workout history
- **Resume workout**: add an **End Workout** button and an **Edit Exercises** option within the active workout sheet so users can make changes mid-session
- **Workout shortcut bar** (floating above the tab bar): repositioned so it doesn't overlap the AI chat button — moved slightly higher or to the left

### 📸 Scan Tab

- **Photo guidelines** cards become tappable — tapping opens a tips sheet with detailed guidance (lighting, distance, pose, clothing tips)

### 🔔 Live Activities & Dynamic Island

- Fix Live Activity to **actually start** when a workout begins (wire up `WorkoutSessionManager` to call `Activity.request()`)
- Live Activity shows workout name, timer, exercise progress bar, and current exercise name
- Dynamic Island compact view shows workout icon + live timer; expanded view shows full progress
- Fix the activity not updating as exercises are completed

### 🏠 Widgets

- Replace the broken "shows time only" widget with two useful widgets:
  - **Small widget**: Today's workout name + exercise count with a "Start" deep link
  - **Medium widget**: Today's workout + latest body scan score side by side

### 🌍 Language Translation Fix

- Audit the `LocalizationService` for missing keys across all languages
- Add missing translations for all keys that currently fall back to English (workout screen labels, settings, coach messages, onboarding steps)

### ⚙️ Settings — Get Pro Banner

- Free users see a creative **"Unlock Pro"** card in the Settings section of the Profile tab
- Styled with a gradient gold/black design, crown icon, and a one-line value prop — taps open the paywall

## Design

- Paywall lifetime option: gold gradient card with a sparkle/trophy icon, "Best Value" badge
- Apple Health page: clean list of toggleable data types with Apple Health pink heart branding
- Rating page: large animated 5-star display, app store rating badge, single "Rate FitAI" CTA button
- Referral "no code" button: uses `.secondary` semantic color for proper light/dark contrast
- Get Pro settings card: compact gradient strip with crown icon, seamless with existing settings list style
- All existing dark/light mode support preserved throughout

