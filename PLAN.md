# Redesign Workout Share Card — Strava-style for Lifting

## What's Changing

A complete redesign of the workout share card that appears after finishing a workout. Replacing the current simple volume-only card with a rich, Strava-inspired share card tailored for lifting.

---

### **Features**

- **Volume Lifted** — total weight moved, displayed as the hero stat at the top
- **Duration** — how long the workout took (e.g. "47 min")
- **Top Set** — the heaviest single set performed (e.g. "Bench Press · 100kg × 8")
- **Estimated Calories** — rough calorie burn estimate based on duration and volume
- **Personal Records** — if any PRs were hit, they're highlighted with a trophy badge
- **Muscle Map** — a body silhouette showing which muscles were worked (primary in red, secondary in amber), automatically choosing front or back view based on which side has more highlighted muscles
- **App Logo & Name** — FitAI branding at the bottom of the card

---

### **Design**

- **Pure transparent background** with clean white text — minimal and bold, Strava-like
- Stats arranged in a **grid layout** (2 columns) for a clean, dense look
- Each stat has a small label above and a large bold value below
- PR section appears conditionally with a gold trophy icon when records are broken
- Muscle map rendered below the stats — single body view (front or back), with a subtle glow behind it
- Thin divider lines separate sections
- FitAI logo and wordmark centered at the very bottom, subtle white at ~40% opacity
- The card has a slight rounded corner and is sized for Instagram Stories sharing  
it should be transparent (png) only texts and muscle map etc should be visible, no background, same as strava

---

### **Layout (Top to Bottom)**

1. **Workout name & focus** — e.g. "Push Day" with date
2. **Stat grid** — Volume, Duration, Top Set, Calories in a 2×2 grid
3. **PR badge** (if applicable) — gold accent, exercise name + weight
4. **Muscle map** — auto-selected front or back body view, primary (red) and secondary (amber) highlights
5. **App branding** — FitAI logo at the bottom0

