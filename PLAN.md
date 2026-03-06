# Equipment validation fix, workout redirect, streak popup, and Pro welcome screen

## What's changing

### 🔧 Fix: Equipment Selection Required
- When you choose "Home" or "Both" on the training location page, you must now select at least 1 piece of equipment before continuing
- The Continue button stays dimmed until equipment is picked
- Selecting "Gym" works as before (no equipment selection needed)

### ➕ "Start Your Workout" Button on 90-Day Preview
- After the 90-day transformation image finishes generating, a new button appears at the bottom: **"Start Your Workout"**
- Tapping it closes the preview and takes you directly to the Plan tab
- Only visible when the transformation has loaded (not during the generating state)

### 🔥 Streak Popup on Scan Page
- The points/flame badge in the top-right corner of the Scan page becomes tappable
- Tapping it opens a small bottom sheet showing:
  - Your current streak number (big and bold)
  - A motivational "Keep it up! 💪" message
  - Weekly streak dots (like on the Plan page)
  - Total workouts completed
- Clean, minimal design — half-height sheet

### 🎉 Welcome Screen After Subscribing
- After completing a purchase on the paywall, a full-screen welcome appears before entering the app
- **Design:**
  - Dark background with a subtle green/purple gradient glow
  - Centered content: crown icon with gold gradient, "Welcome to Fit AI Pro" headline, premium subtext
  - Soft gold "Pro Activated" badge with gentle glow
  - "Start My Journey" button at the bottom with a subtle glowing border effect
- **Animations:**
  - Content fades in from the bottom with a slight scale-up
  - Haptic feedback on appear (success feel)
  - Subtle pulsing glow behind the crown icon
- **Behavior:**
  - No scrolling, no clutter — one clean screen
  - Tapping "Start My Journey" completes onboarding and enters the app
  - Only shows once when first subscribing during onboarding
