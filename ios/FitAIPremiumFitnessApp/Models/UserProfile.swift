import Foundation

nonisolated struct UserProfile: Codable, Sendable {

    // customPhotoData is excluded from Codable — stored separately in FileManager
    enum CodingKeys: String, CodingKey {
        case name, username, email, avatarSystemName, bio, gender
        case workoutsPerWeek, preferredTrainingDays, trainingExperience, trainingLocation, primaryGoal
        case holdingBack, goals, trainingConfidence, availableEquipment
        case heightCm, weightKg, usesMetric, dateOfBirth, selectedLanguage
        case referralCode, referredByCode, friendsReferredCount
        case isPremium, spinDiscount
        case totalScans, totalWorkouts, currentStreak, points, tier
        case latestScore, lastScanDate, weakPoints, strongPoints
        case workoutLogs, completedDaysThisWeek, weekStartDate
        case forceDarkMode, freeScansEarned
        case privacyMode, allowUsernameSearch, usernameChangedAt
        case goalProjectionURL, goalProjectionGeneratedAt
        case lastProgressionCheckAt
        case profilePhotoURL
        case aiChatMessagesUsed
        case photoConsentVersion, photoConsentGrantedAt
        case photoImprovementOptIn
        case workoutModeRawValue = "workoutMode"
    }

    /// How the user wants the Workouts tab to behave. Set on first launch
    /// of the tab via `WorkoutOnboardingChoiceView`. `unset` is the default
    /// for fresh installs — the choice screen is shown until this is set.
    enum WorkoutMode: String, Codable, Sendable {
        case unset
        case aiGenerated         // App generates a 7-day plan from profile
        case userBuilt           // Templates only, no AI plan
        case userPlanReviewed    // User pasted their plan, AI imported it

        var label: String {
            switch self {
            case .unset: return "Not chosen"
            case .aiGenerated: return "AI-generated plan"
            case .userBuilt: return "Custom templates"
            case .userPlanReviewed: return "AI-reviewed plan"
            }
        }
    }

    var name: String = ""
    var username: String = ""
    var email: String = ""
    var avatarSystemName: String = "person.crop.circle.fill"
    var bio: String = ""
    var gender: String = ""
    var workoutsPerWeek: Int = 3
    /// Days of the week the user prefers to train. Stored as uppercase
    /// 3-letter labels ("MON", "TUE", …) to match the existing
    /// `completedDaysThisWeek` convention. Optional so old profile blobs
    /// without this key still decode cleanly via synthesized Codable.
    var preferredTrainingDays: [String]? = nil
    var trainingExperience: String = ""
    var trainingLocation: String = ""
    var primaryGoal: String = ""
    var holdingBack: [String] = []
    var goals: [String] = []
    var trainingConfidence: Int = 5
    var availableEquipment: [String] = []
    var heightCm: Double = 175
    var weightKg: Double = 75
    var usesMetric: Bool = false
    var dateOfBirth: Date? = nil
    var selectedLanguage: String = "English"
    /// User's own outbound referral code — generated on signup, shared with friends.
    var referralCode: String = ""
    /// Code the user entered during onboarding (a friend's code).
    var referredByCode: String = ""
    /// Server-attributed count of friends who signed up using `referralCode`. Reaches 3 → free scan unlock.
    var friendsReferredCount: Int = 0
    var isPremium: Bool = false
    var spinDiscount: Int? = nil
    var totalScans: Int = 0
    var totalWorkouts: Int = 0
    var currentStreak: Int = 0
    var points: Int = 0
    var tier: String = "Bronze"
    var latestScore: Double? = nil
    var lastScanDate: Date? = nil
    var weakPoints: [String] = []
    var strongPoints: [String] = []
    var workoutLogs: [WorkoutLog] = []
    var completedDaysThisWeek: [String] = []
    var weekStartDate: Date? = nil
    var customPhotoData: Data? = nil
    /// Public URL of the user's avatar in the `profile_photos` Supabase
    /// Storage bucket. Set after a successful upload from EditProfile;
    /// nil when the user uses an SF Symbol avatar instead. Surfaces on
    /// other devices via `restoreFromCloud` so avatars follow the user.
    var profilePhotoURL: String? = nil
    var forceDarkMode: Bool = false
    /// Bonus scans earned via referral unlock (each 3 referrals → +1). Decremented on use.
    var freeScansEarned: Int = 0

    // MARK: - Social privacy

    /// Who can see this profile's social activity.
    /// `public` — discoverable in search, activity feed visible to everyone (minus blocks).
    /// `friends_only` — discoverable in search, activity feed only visible to friends.
    /// `private` — not in search results; only friends can see anything.
    var privacyMode: String = "public"
    /// When false, this profile is excluded from username search results entirely.
    var allowUsernameSearch: Bool = true
    /// Timestamp of last username change — used to enforce ~30-day cooldown.
    var usernameChangedAt: Date? = nil

    // MARK: - Goal projection ("Future you")

    /// Public URL of the AI-generated goal physique projection. Generated
    /// from the user's most recent body scan + their primary goal. Surfaced
    /// in PlanPreview, Profile, and the cancel-subscription confirmation
    /// to anchor the user to their stated outcome.
    var goalProjectionURL: String? = nil
    /// Timestamp of the last regeneration. Edge function enforces a 90-day
    /// cooldown server-side; client uses this to display "next regen in N days".
    var goalProjectionGeneratedAt: Date? = nil

    // MARK: - Auto-progression (Pro)

    /// When the AI coach last ran the weekly progression check. The check
    /// is throttled to once every 7 days per user — re-asking sooner is
    /// wasteful and noisy. Nil = never checked.
    var lastProgressionCheckAt: Date? = nil

    /// Whether the user can see an unblurred scan result. Umax
    /// pattern: every free user's scan result is locked at reveal,
    /// the dopamine of "show me my score" is the conversion hook.
    /// Premium unlocks all scans; sharing with 3 friends earns one
    /// `freeScansEarned` credit that unlocks the next scan.
    var canScanFree: Bool {
        if isPremium { return true }
        if freeScansEarned > 0 { return true } // referral-unlocked scans
        return false
    }

    /// Number of days of workout/log history a user can see in
    /// charts, lists, and insights. Free tier = 30 days; Pro =
    /// effectively unlimited. Underlying storage and PR detection
    /// always operate on the full log — this only filters what the
    /// user sees in history-rendering UI.
    var visibleHistoryWindowDays: Int {
        isPremium ? .max : 30
    }

    /// Cutoff date for history views. Anything before this is
    /// hidden behind the Pro paywall on the surfaces that display
    /// it. Premium returns `.distantPast` (effectively no cutoff).
    var historyCutoffDate: Date {
        guard !isPremium else { return .distantPast }
        return Calendar.current.date(
            byAdding: .day,
            value: -visibleHistoryWindowDays,
            to: Date()
        ) ?? .distantPast
    }

    // MARK: - Entitlements

    /// Lifetime count of outbound AI Coach messages. Free users get 5
    /// messages total (not per day) before hitting the paywall — research
    /// shows lifetime quotas convert better than daily because daily
    /// resets feel patronizing.
    var aiChatMessagesUsed: Int = 0
    /// Free-tier AI Coach lifetime quota.
    static let freeAIChatQuota: Int = 5

    var canSendAICoachMessage: Bool {
        isPremium || aiChatMessagesUsed < UserProfile.freeAIChatQuota
    }

    /// Free users cannot *create* challenges (research recommendation —
    /// keeps virality flywheel intact while gating outbound creation).
    /// They can still receive and view challenges from paid friends.
    var canCreateChallenge: Bool { isPremium }

    /// "Future you" goal projection card is premium-only. Free users see
    /// nothing in its place — no broken-image placeholder.
    var canSeeGoalProjection: Bool { isPremium }

    // MARK: - Photo consent (GDPR Art. 9(2)(a) explicit consent)

    /// Bumped whenever the consent text changes — when this is below the
    /// `currentPhotoConsentVersion` constant the modal re-prompts. Stored
    /// as Int so we never confuse "not consented" (0) with an old version.
    var photoConsentVersion: Int = 0
    /// Timestamp of the most recent grant. Used in audit trails / data
    /// access requests. nil if the user has never consented.
    var photoConsentGrantedAt: Date? = nil
    /// Optional opt-in toggle from the consent modal — anonymized,
    /// aggregated stats. Default OFF. Pre-checked is a GDPR dark pattern.
    var photoImprovementOptIn: Bool = false

    /// Persisted workout-tab mode. Stored as a raw string and Optional so
    /// old profile blobs without this key still decode cleanly (synthesized
    /// Codable rejects missing non-optional keys; Optional<String> tolerates
    /// them). Public so synthesized Codable definitely sees it without any
    /// access-level edge cases.
    var workoutModeRawValue: String? = nil

    /// Read/write accessor over `workoutModeRawValue`. The rest of the app
    /// treats `.unset` as "needs onboarding".
    var workoutMode: WorkoutMode {
        get {
            guard let raw = workoutModeRawValue,
                  let mode = WorkoutMode(rawValue: raw) else { return .unset }
            return mode
        }
        set { workoutModeRawValue = newValue.rawValue }
    }

    /// Current consent text/version. Bump this when material changes are
    /// made to what photos are uploaded, where, or for how long.
    static let currentPhotoConsentVersion: Int = 1

    /// True if the user has granted consent for the current policy version.
    var hasGrantedPhotoConsent: Bool {
        photoConsentVersion >= UserProfile.currentPhotoConsentVersion
    }
}
