import Foundation

/// Local persistence for body measurements (Hevy / Strong-style), now backed
/// by Supabase `body_measurements` so measurements survive logout/reinstall.
/// Mutations write locally first then push to cloud in a detached task —
/// caller can invoke methods synchronously, sync happens out-of-band.
@Observable
@MainActor
final class BodyMeasurementService {
    static let shared = BodyMeasurementService()

    private let storageKey = "bodyMeasurements.v1"

    private(set) var measurements: [BodyMeasurement]

    /// Set by AppState during sign-in so push methods know the cloud user
    /// to write to. nil while signed-out — measurements are then local-only
    /// until the user authenticates.
    var currentUserId: String? = nil

    private init() {
        if let data = UserDefaults.standard.data(forKey: "bodyMeasurements.v1"),
           let decoded = try? JSONDecoder().decode([BodyMeasurement].self, from: data) {
            self.measurements = decoded.sorted(by: { $0.date > $1.date })
        } else {
            self.measurements = []
        }
    }

    func add(_ measurement: BodyMeasurement) {
        measurements.append(measurement)
        measurements.sort(by: { $0.date > $1.date })
        persist()
        pushToCloud(measurement)
    }

    func update(_ measurement: BodyMeasurement) {
        guard let idx = measurements.firstIndex(where: { $0.id == measurement.id }) else { return }
        measurements[idx] = measurement
        measurements.sort(by: { $0.date > $1.date })
        persist()
        pushToCloud(measurement)
    }

    func remove(id: String) {
        measurements.removeAll { $0.id == id }
        persist()
        if let userId = currentUserId {
            Task.detached {
                await SupabaseSyncService.shared.deleteBodyMeasurement(userId: userId, id: id)
            }
        }
    }

    /// Replace the entire local cache — used by `AppState.restoreFromCloud`
    /// to hydrate after a fresh sign-in. Skips cloud push since the source
    /// of truth is already cloud.
    func replaceAll(_ list: [BodyMeasurement]) {
        measurements = list.sorted(by: { $0.date > $1.date })
        persist()
    }

    /// Wipe local cache (called on logout). Cloud copy is preserved so the
    /// user gets it back on next sign-in.
    func clearLocal() {
        measurements = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func pushToCloud(_ m: BodyMeasurement) {
        guard let userId = currentUserId else { return }
        Task.detached {
            await SupabaseSyncService.shared.upsertBodyMeasurement(userId: userId, measurement: m)
        }
    }

    /// Most recent measurement (or nil if empty). Surfaced on the
    /// Measurements summary card.
    var latest: BodyMeasurement? { measurements.first }

    /// Time-series of weight readings (oldest → newest). Used for the
    /// weight-over-time chart on the measurements screen.
    var weightSeries: [(Date, Double)] {
        measurements
            .compactMap { m in m.weightKg.map { (m.date, $0) } }
            .sorted(by: { $0.0 < $1.0 })
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(measurements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
