import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    // Name capture early — every downstream screen can address the user
    // by name. Personalization-bias lift on subsequent commitment.
    case name
    case gender
    case workoutsPerWeek
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
    // Engineered "AI is building your plan" moment. Slow checklist,
    // ~6 seconds, drives the effort heuristic so the paywall lands at peak
    // anticipation (Umax/Gravl pattern: paywall BEFORE results reveal, not
    // after). The user has invested time + sees the AI worked for them, but
    // hasn't seen the plan yet — that's the moment of maximum willingness.
    case planLoading
    // Paywall sits directly after planLoading and before planPreview so the
    // user pays (or invites 3 friends) to "unlock my results". Sign-up moved
    // AFTER planPreview so we don't gate the conversion moment behind a
    // form (Gravl: "hard paywall before sign-in").
    case paywall
    case welcomePro
    case spinWheel
    case planPreview
    case referralCode
    case signUp
    // Username comes right after sign-up — needs an authenticated user to
    // claim a unique handle (RLS).
    case username
    case enableNotifications
    case appleHealth
}
