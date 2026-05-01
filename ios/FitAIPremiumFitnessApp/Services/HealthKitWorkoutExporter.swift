import Foundation
import HealthKit

/// Mirrors finished workouts to Apple Health as `HKWorkout` entries so the
/// user's Activity rings update and Apple Watch reflects strength sessions.
final class HealthKitWorkoutExporter: @unchecked Sendable {
    static let shared = HealthKitWorkoutExporter()

    private let store = HKHealthStore()

    private init() {}

    /// Saves a workout. Silent no-op if HealthKit is unavailable or the user
    /// hasn't granted write permission yet — we never want a Health hiccup
    /// to block the local "workout finished" UX.
    func save(startDate: Date, durationSeconds: Int, exerciseCount: Int) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let endDate = startDate.addingTimeInterval(TimeInterval(max(durationSeconds, 60)))

        // Rough estimate: strength training averages ~5 kcal/min for an
        // average adult. Conservative; refines once we add per-set tracking.
        let durationMinutes = Double(durationSeconds) / 60.0
        let estimatedKcal = durationMinutes * 5.0

        let energy = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedKcal)
        let energySample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: energy,
            start: startDate,
            end: endDate
        )

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())

        Task {
            do {
                try await builder.beginCollection(at: startDate)
                try await builder.addSamples([energySample])
                try await builder.endCollection(at: endDate)
                _ = try await builder.finishWorkout()
            } catch {
                // Permission denied / write-disabled: not a user-visible error.
                print("[HealthKit] workout export skipped: \(error.localizedDescription)")
            }
        }
    }
}
