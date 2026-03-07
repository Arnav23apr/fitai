# Interactive Muscle Heat Maps with MuscleMap Library

## Features

- **Workout Muscle Map** — Each workout detail sheet shows a front + back body diagram highlighting which muscles that workout targets, with primary muscles in red and secondary muscles in gold/yellow
- **Weekly Volume Heat Map** — The Plan tab gets a "Muscle Activity" card showing a body map colored by how much you've trained each muscle group this week (cold → hot gradient based on total sets)
- **Tap to Explore** — Tap any muscle on the body to see which exercises target it, how many sets you've done, and your total volume for that muscle
- **Smart Muscle Mapping** — Every exercise in your plan is automatically mapped to its primary and secondary muscle groups (e.g. Bench Press → primary: Chest, secondary: Triceps + Front Delts)
- **Legend** — Clear color legend below the body map showing what each color intensity means

## Design

- **Dark-themed body diagrams** matching your app's existing dark aesthetic
- Front and back body views displayed side-by-side, just like in your reference image
- Primary muscles shown in vibrant red, secondary muscles in warm gold/amber
- Weekly heat map uses a gradient scale — gray (untrained) → light orange → deep red (heavily trained)
- Tapping a muscle shows a compact popup/sheet with exercise names, sets done, and volume
- Smooth spring animations when muscles highlight on appearance
- The weekly overview card uses a subtle material background with rounded corners, consistent with existing Plan tab cards

## Screens & Placement

- **Workout Detail Sheet** — New "Muscles Targeted" section near the top showing the front + back body with this workout's muscles lit up in primary (red) and secondary (gold) colors
- **Plan Tab** — New "Weekly Muscle Activity" card (collapsible) showing a heat map of all muscles trained this week, colored by volume intensity
- **Muscle Detail Popup** — When tapping a muscle, a small sheet appears listing the exercises hitting that muscle, total sets, and total volume this week

## Technical Approach

- Install the **MuscleMap** Swift package (v1.6.0) — provides 36 SVG-based muscle groups with built-in highlighting, heatmaps, and tap detection
- Create a mapping service that converts your existing exercise muscle group strings (e.g. "Chest", "Quads", "Biceps") to the MuscleMap library's muscle identifiers, including primary/secondary classification
- The weekly heat map aggregates completed workout logs from the current week to calculate per-muscle intensity

