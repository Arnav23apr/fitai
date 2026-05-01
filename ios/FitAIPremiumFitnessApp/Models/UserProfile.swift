import Foundation

nonisolated struct UserProfile: Codable, Sendable {

    // customPhotoData is excluded from Codable — stored separately in FileManager
    enum CodingKeys: String, CodingKey {
        case name, username, email, avatarSystemName, bio, gender
        case workoutsPerWeek, trainingExperience, trainingLocation, primaryGoal
        case holdingBack, goals, trainingConfidence
        case heightCm, weightKg, usesMetric, dateOfBirth, selectedLanguage
        case referralCode, referredByCode, friendsReferredCount
        case isPremium, spinDiscount
        case totalScans, totalWorkouts, currentStreak, points, tier
        case latestScore, lastScanDate, weakPoints, strongPoints
        case workoutLogs, completedDaysThisWeek, weekStartDate
        case forceDarkMode, freeScansEarned
    }

    var name: String = ""
    var username: String = ""
    var email: String = ""
    var avatarSystemName: String = "person.crop.circle.fill"
    var bio: String = ""
    var gender: String = ""
    var workoutsPerWeek: Int = 3
    var trainingExperience: String = ""
    var trainingLocation: String = ""
    var primaryGoal: String = ""
    var holdingBack: [String] = []
    var goals: [String] = []
    var trainingConfidence: Int = 5
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
    var forceDarkMode: Bool = false
    /// Bonus scans earned via referral unlock (each 3 referrals → +1). Decremented on use.
    var freeScansEarned: Int = 0

    /// Whether the user can trigger a scan without hitting the paywall.
    /// First scan ever is free; after that, only premium or earned-scan users.
    var canScanFree: Bool {
        if isPremium { return true }
        if totalScans == 0 { return true }    // lifetime first-scan freebie
        if freeScansEarned > 0 { return true } // referral-unlocked scans
        return false
    }
}
