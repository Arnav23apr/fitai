# Resume Workout + Dynamic Island Live Tracking

## Features

### 🔄 Resume Workout

- **Persistent workout session** — When you start a workout, your progress (completed exercises, timer, sets logged) is saved automatically so it survives closing the sheet, switching tabs, or even closing the app
- **Floating resume banner** — A compact pill appears at the bottom of every tab showing the active workout name, elapsed time, and a tap-to-resume action
- **Auto-reopen on Plan tab** — When you navigate back to the Plan tab, the workout sheet automatically re-opens with all your progress intact
- **Explicit end required** — The workout only ends when you tap "Complete Workout" or "Finish Early" — never by accident from dismissing the sheet

### 🏝️ Dynamic Island & Live Activity

- **Live Activity starts automatically** when you begin a workout
- **Compact Dynamic Island** — Left side shows a dumbbell icon, right side shows the elapsed workout timer
- **Expanded Dynamic Island** — Shows workout name, elapsed timer, current exercise name, progress (e.g. "3/6 exercises done"), and rest timer countdown when active
- **Lock Screen banner** — Full workout dashboard below the clock: workout name, timer, progress bar, current exercise, and rest countdown
- **Real-time updates** — Timer ticks every second, rest countdown updates live, exercise progress updates as you complete each one
- **Auto-ends** when you complete or finish the workout early

---

## Design

### Floating Resume Banner

- A compact glass-style pill that floats above the tab bar on all screens
- Shows a green pulsing dot (indicating active), the workout name truncated, and the running timer
- Tapping it re-opens the workout sheet with all progress restored
- Slides up with a spring animation when a workout is active, slides away when completed
- Uses the iOS 26 liquid glass effect (with material fallback for iOS 18)

### Dynamic Island — Compact

- **Leading:** Dumbbell SF Symbol (green tint)
- **Trailing:** Elapsed time as a running timer (e.g. `12:34`)

### Dynamic Island — Expanded

- **Leading:** Workout icon + workout name
- **Trailing:** Running timer
- **Bottom:** Progress bar showing exercises completed, current exercise name, and rest timer countdown (when resting)

### Lock Screen Live Activity

- Clean card with the workout name and elapsed timer at the top
- Horizontal progress bar showing exercise completion
- Current exercise name and "X of Y exercises" label
- Rest timer countdown displayed prominently when between sets

---

## Technical Scope

### New Screens / Components

- **Floating resume pill** — Overlay on `MainTabView`, visible on all tabs during an active workout
- **Widget extension target** — Required for Dynamic Island and Live Activity rendering

### Changes to Existing Screens

- **Workout Detail Sheet** — Saves/restores state from a shared session manager instead of local `@State`
- **Set Logging Sheet** — Updates the shared session when rest timer starts/stops
- **Main Tab View** — Shows the floating resume pill overlay; auto-reopens workout on Plan tab
- **Plan View** — Detects active session and re-presents the workout sheet

### Behind the Scenes

- A new workout session manager that persists the active workout state (exercise progress, timer start, rest timer state)
- Live Activity attributes and content state for ActivityKit integration
- Timer updates pushed to the Dynamic Island and Lock Screen in real-time

