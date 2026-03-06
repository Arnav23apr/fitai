# Replace weight & reps text fields with iOS wheel pickers

**What changes**

Replace the current typed text fields for **weight** and **reps** in the workout set logging screen with native iOS wheel pickers (like the Clock app timer picker).

**How it will work**

- **Weight picker**: Scrollable wheel starting at 0, incrementing by 0.5 (0, 0.5, 1, 1.5, 2, … up to 300)
- **Reps picker**: Scrollable wheel starting at 0, incrementing by 1 (0, 1, 2, 3, … up to 100)
- Both pickers are compact inline wheels that sit exactly where the current text fields are — no keyboard pops up
- Pre-filled with previous session values, so users just scroll slightly to adjust
- Completed sets become non-interactive (same as today)
- Unit label (KG/LBS) and "REPS" labels remain above each picker
- The "×" separator between weight and reps stays

**Why this is better**

- No keyboard blocking the view — all sets stay visible
- Faster adjustments (scroll vs tap → type → dismiss)
- Zero typos or weird decimal inputs
- Feels premium and native iOS
- Familiar interaction from the Clock app

