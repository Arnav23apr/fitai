import Foundation

/// A snapshot of body measurements taken on a given date. Hevy/Strong both
/// surface this as a separate "Measurements" tab — used to track non-strength
/// progress (waist size during a cut, arm size during a bulk, etc).
nonisolated struct BodyMeasurement: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var date: Date
    /// Stored in cm + kg internally; UI converts on the fly using
    /// `UserProfile.usesMetric`.
    var weightKg: Double?
    var chestCm: Double?
    var waistCm: Double?
    var hipsCm: Double?
    var leftArmCm: Double?
    var rightArmCm: Double?
    var leftThighCm: Double?
    var rightThighCm: Double?
    var leftCalfCm: Double?
    var rightCalfCm: Double?
    var neckCm: Double?
    var shouldersCm: Double?
    var notes: String

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        weightKg: Double? = nil,
        chestCm: Double? = nil,
        waistCm: Double? = nil,
        hipsCm: Double? = nil,
        leftArmCm: Double? = nil,
        rightArmCm: Double? = nil,
        leftThighCm: Double? = nil,
        rightThighCm: Double? = nil,
        leftCalfCm: Double? = nil,
        rightCalfCm: Double? = nil,
        neckCm: Double? = nil,
        shouldersCm: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.chestCm = chestCm
        self.waistCm = waistCm
        self.hipsCm = hipsCm
        self.leftArmCm = leftArmCm
        self.rightArmCm = rightArmCm
        self.leftThighCm = leftThighCm
        self.rightThighCm = rightThighCm
        self.leftCalfCm = leftCalfCm
        self.rightCalfCm = rightCalfCm
        self.neckCm = neckCm
        self.shouldersCm = shouldersCm
        self.notes = notes
    }
}
