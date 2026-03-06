# Bodyweight Exercise Toggle & Update Weight/Height in Profile

## Features

- **Bodyweight toggle on eligible exercises** — When logging sets for exercises like push-ups, pull-ups, dips, bodyweight squats, etc., a "Using Bodyweight" toggle appears at the top of the set logging screen
- **Reps-only input for bodyweight mode** — When bodyweight is toggled on, the weight picker is hidden and replaced with a label showing "Your Weight: 75kg" (pulled from your profile). Only the reps picker remains adjustable
- **Automatic volume calculation** — When bodyweight is active, your profile weight is automatically used to calculate volume (weight × reps), so your progress tracking stays accurate
- **Smart exercise detection** — The app knows which exercises can be done with bodyweight (push-ups, pull-ups, chin-ups, dips, bodyweight squats, lunges, planks, crunches, leg raises, etc.) and only shows the toggle for those
- **Update Weight & Height button** — A new card appears right below your user info card on the Profile tab, showing your current height and weight with an edit button
- **Weight & Height editor sheet** — Tapping the card opens a half-height sheet with wheel pickers (same style as onboarding) to update your height and weight
- **AI & volume awareness** — When you finish a bodyweight exercise, the AI context and exercise logs take your body weight into account for those exercises

## Design

- **Bodyweight toggle** — A clean pill-shaped toggle at the top of the set logging sheet, with a "figure.walk" icon and "Bodyweight" label. When active, it glows green with a subtle highlight
- **Weight display in bodyweight mode** — Instead of the weight wheel picker, a rounded card shows "BW" with your weight value underneath (e.g. "75 kg"), styled with a soft green tint
- **Profile weight/height card** — A compact card below the user info card showing height and weight side by side with their values, a subtle scale icon, and a pencil edit button. Matches the existing profile card style
- **Height & Weight sheet** — Half-height sheet with the same wheel picker layout as onboarding (imperial/metric segmented control, height and weight pickers side by side), with a Save button

## Screens

- **Set Logging Sheet (updated)** — For bodyweight-eligible exercises, a toggle appears below the exercise header. When on, weight pickers lock to your body weight and show a clean "BW" label instead
- **Profile Tab (updated)** — New weight & height card appears between the user info card and the stats card
- **Weight & Height Editor Sheet (new)** — Half-height sheet with imperial/metric toggle and wheel pickers to update your measurements
