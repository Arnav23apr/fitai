import Foundation

nonisolated struct UserProfile: Codable, Sendable {
    var name: String = ""
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
    var referralCode: String = ""
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
}
