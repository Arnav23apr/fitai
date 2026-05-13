import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    // Name capture early — every downstream screen can address the user
    // by name. Personalization-bias lift on subsequent commitment.
    case name
    case gender
    case workoutsPerWeek
    case preferredTrainingDays
    case trainingExperience
    case trainingLocation
    case primaryGoal
    case hardTruth
    // TrustUs is intentionally placed BEFORE the sensitive personal-data
    // questions (DOB, height, weight). Privacy reassurance has to justify
    // the ask, not retro-actively defend it.
    case trustUs
    case dateOfBirth
    case heightWeight
    case holdingBack
    case physiqueReward
    case goals
    case confidence
    case onePercent
    case resultsGraph
    // Pseudo-contract — explicit commitment lifts retention 30%
    // (Cialdini commitment-and-consistency).
    case commitment
    // Plan reveal sits directly after the I'm-in moment. The user
    // earned the plan; we show it. PlanPreviewView carries its own
    // transient "Building your plan…" beat into the actual reveal,
    // so the dedicated plan-loading step was removed earlier as a
    // duplicate of that text state.
    case planPreview
    // Paywall used to sit here. It has been pulled out of the
    // linear onboarding flow entirely — FitAI now follows the Umax
    // pattern: free users complete onboarding, reach the main app,
    // and only hit the paywall when they try to unblur a scan
    // result on the Scan tab (with the share-with-3-friends escape
    // hatch as the soft path). PaywallView / WelcomeProView /
    // SpinWheelView struct files still exist and are presented as
    // sheets from ScanView and other gating moments — they're just
    // no longer onboarding "steps".
    case referralCode
    case signUp
    // Username comes right after sign-up — needs an authenticated user to
    // claim a unique handle (RLS).
    case username
    case enableNotifications
    case appleHealth
}
