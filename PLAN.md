# Redesign Workout Share Card — Strava-style for Lifting

## What's Changing

A complete redesign of the workout share card that appears after finishing a workout. Replacing the current simple volume-only card with a rich, Strava-inspired share card tailored for lifting.

---

### **Features**

- [x] **Volume Lifted** — total weight moved, displayed as the hero stat at the top
- [x] **Duration** — how long the workout took (e.g. "47 min")
- [x] **Top Set** — the heaviest single set performed (e.g. "Bench Press · 100kg × 8")
- [x] **Estimated Calories** — rough calorie burn estimate based on duration and volume
- [x] **Personal Records** — if any PRs were hit, they're highlighted with a trophy badge
- [x] **Muscle Map** — a body silhouette showing which muscles were worked (primary in red, secondary in amber), automatically choosing front or back view based on which side has more highlighted muscles
- [x] **App Logo & Name** — FitAI branding at the bottom of the card

---

### **Design**

- [x] **Pure transparent background** with clean white text — minimal and bold, Strava-like
- [x] Stats arranged in a **grid layout** (2 columns) for a clean, dense look
- [x] Each stat has a small label above and a large bold value below
- [x] PR section appears conditionally with a gold trophy icon when records are broken
- [x] Muscle map rendered below the stats — single body view (front or back), with a subtle glow behind it
- [x] Thin divider lines separate sections
- [x] FitAI logo and wordmark centered at the very bottom, subtle white at ~40% opacity
- [x] Transparent PNG export (renderer.isOpaque = false)

---

### **Layout (Top to Bottom)**

1. [x] **Workout name & focus** — e.g. "Push Day" with date
2. [x] **Stat grid** — Volume, Duration, Top Set, Calories in a 2×2 grid
3. [x] **PR badge** (if applicable) — gold accent, exercise name + weight
4. [x] **Muscle map** — auto-selected front or back body view, primary (red) and secondary (amber) highlights
5. [x] **App branding** — FitAI logo at the bottom

✅ **COMPLETE**
