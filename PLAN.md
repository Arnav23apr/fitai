# AI Smart Presets, Scan History Graph & Light Theme Fix

## Features

### 1. AI-Powered Weight & Rep Presets (Progressive Overload)

- When the AI generates your weekly workout plan, it will also generate **recommended weight and reps for each set** of every exercise — personalized to your height, weight, gender, experience level, goals, and training confidence
- **First-time users** get smart defaults (e.g. a beginner bench pressing might start at 40kg × 12 reps, while an advanced lifter starts at 100kg × 8 reps)
- Each week when the plan refreshes, weights **automatically increase slightly** (progressive overload) — e.g. +2.5kg for upper body, +5kg for lower body compound lifts
- You can always **change any preset value** — the pickers still work exactly as before, just pre-filled with smart suggestions
- For **bodyweight exercises** (push-ups, pull-ups, dips, etc.), the AI sets appropriate rep ranges instead of weights
- When you do a **weighted bodyweight exercise** (e.g. weighted push-ups with 25kg), the app calculates your **total load** = your body weight + added weight, and shows it as a note

### 2. Smarter Bodyweight Toggle

- Exercises that **require gym equipment** (bench press, lat pulldown, cable fly, leg press, etc.) will show the bodyweight toggle **grayed out** with a small note "Requires equipment"
- Exercises that **can be done with bodyweight** (push-ups, pull-ups, dips, squats, lunges, etc.) keep the toggle working as normal
- When bodyweight is OFF and the user adds weight to a bodyweight-eligible exercise, the app shows the **total effective weight** (body weight + added weight) as a helpful note below the set

### 3. Scan History Graph (Replaces List)

- The scan history list in your Profile is **replaced by a smooth curved line chart** with a gradient fill underneath
- The line color changes based on score ranges (green for high scores, orange/yellow for mid, red for low)
- Each scan appears as a **tappable dot/mark** on the graph
- Tapping a data point opens a **mini detail card** showing the score, date, rank, strong points, and weak points from that scan
- If you only have one scan, it shows a single point with a horizontal reference line
- Empty state still shows the "No scans yet" placeholder

### 4. Welcome Screen Light Theme Fix

- The Welcome/onboarding screen will properly adapt to **light mode** — white background, dark text, and correct logo variant
- Currently it already checks `colorScheme`, but the background color will be verified to use the system background so it works in both themes consistently

## Design

### Weight Presets

- When opening an exercise for the first time, the weight and rep pickers are **pre-scrolled to the AI-recommended values** instead of starting at 0
- A subtle "AI Suggested" label appears near the preset values in a small pill badge
- Returning to an exercise uses your **last logged values** as before (existing behavior preserved)

### Scan History Graph

- Smooth curved line with a soft gradient fill from the line color down to transparent
- Data points shown as small filled circles on the line
- X-axis shows dates, Y-axis shows score (0–10)
- Tapping a point expands a floating card with scan details
- Clean, minimal design matching the existing profile page style
- Built with Swift Charts for a native iOS look

### Bodyweight Toggle

- "Requires equipment" toggle is visually dimmed with reduced opacity
- When doing weighted bodyweight exercises, a small info row shows "Total load: 100kg (75kg BW + 25kg added)" in a subtle card below the set

## Pages / Screens

- **Profile Tab** — Scan history list replaced with interactive line chart graph
- **Set Logging Sheet** — Weight/rep pickers pre-filled with AI suggestions; bodyweight toggle disabled for equipment-only exercises; total load display for weighted bodyweight exercises
- **Workout Plan Generation** — AI prompt updated to also return recommended weights and reps per set for each exercise
- **Welcome Screen** — Background and text colors properly adapt to light/dark theme

