import SwiftUI
import ActivityKit

@Observable
@MainActor
class WorkoutSessionManager {
    static let shared = WorkoutSessionManager()

    var isActive: Bool = false
    var workoutDayLabel: String = ""
    var workoutName: String = ""
    var workoutIcon: String = ""
    var workoutFocusAreas: [String] = []
    var workoutIsWeakPointFocus: Bool = false
    var exerciseIds: [String] = []
    var exerciseNames: [String] = []
    var completedExerciseIds: Set<String> = []
    var startTime: Date? = nil
    var elapsedSeconds: Int = 0
    var earnedPRPoints: Int = 0
    var exercisePRs: Set<String> = []
    var prExerciseNames: [String] = []
    var exerciseVolumes: [String: Double] = [:]
    var currentExerciseName: String = ""
    var isResting: Bool = false
    var restSecondsRemaining: Int = 0

    private var timer: Timer?
    private var activity: Activity<WorkoutActivityAttributes>?

    private init() {
        restoreSession()
    }

    var totalExercises: Int { exerciseIds.count }
    var completedCount: Int { completedExerciseIds.count }
    var allCompleted: Bool { completedExerciseIds.count == exerciseIds.count && !exerciseIds.isEmpty }

    func startWorkout(workout: WorkoutDay) {
        isActive = true
        workoutDayLabel = workout.dayLabel
        workoutName = workout.name
        workoutIcon = workout.icon
        workoutFocusAreas = workout.focusAreas
        workoutIsWeakPointFocus = workout.isWeakPointFocus
        exerciseIds = workout.exercises.map(\.id)
        exerciseNames = workout.exercises.map(\.name)
        completedExerciseIds = []
        startTime = Date()
        elapsedSeconds = 0
        earnedPRPoints = 0
        exercisePRs = []
        prExerciseNames = []
        exerciseVolumes = [:]
        currentExerciseName = workout.exercises.first?.name ?? ""
        isResting = false
        restSecondsRemaining = 0

        startTimer()
        persistSession()
        startLiveActivity()
    }

    func markExerciseCompleted(_ exerciseId: String, exerciseName: String, volume: Double, hitPR: Bool) {
        completedExerciseIds.insert(exerciseId)
        exerciseVolumes[exerciseId] = volume

        if hitPR {
            earnedPRPoints += 50
            exercisePRs.insert(exerciseId)
            prExerciseNames.append(exerciseName)
        }

        let nextIndex = exerciseIds.firstIndex(where: { !completedExerciseIds.contains($0) })
        if let idx = nextIndex {
            currentExerciseName = exerciseNames[idx]
        } else {
            currentExerciseName = ""
        }

        persistSession()
        updateLiveActivity()
    }

    func updateRestTimer(isResting: Bool, secondsRemaining: Int) {
        self.isResting = isResting
        self.restSecondsRemaining = secondsRemaining
        updateLiveActivity()
    }

    func endSession() {
        isActive = false
        timer?.invalidate()
        timer = nil
        clearPersistedSession()
        endLiveActivity()
    }

    func resumeIfNeeded() {
        if isActive && timer == nil {
            startTimer()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.startTime else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Persistence

    private let sessionKey = "activeWorkoutSession"

    private func persistSession() {
        let data: [String: Any] = [
            "workoutDayLabel": workoutDayLabel,
            "workoutName": workoutName,
            "workoutIcon": workoutIcon,
            "workoutFocusAreas": workoutFocusAreas,
            "workoutIsWeakPointFocus": workoutIsWeakPointFocus,
            "exerciseIds": exerciseIds,
            "exerciseNames": exerciseNames,
            "completedExerciseIds": Array(completedExerciseIds),
            "startTime": startTime?.timeIntervalSince1970 ?? 0,
            "earnedPRPoints": earnedPRPoints,
            "exercisePRIds": Array(exercisePRs),
            "prExerciseNames": prExerciseNames,
            "currentExerciseName": currentExerciseName
        ]
        UserDefaults.standard.set(data, forKey: sessionKey)
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.dictionary(forKey: sessionKey),
              let startInterval = data["startTime"] as? Double,
              startInterval > 0 else { return }

        let start = Date(timeIntervalSince1970: startInterval)
        let elapsed = Int(Date().timeIntervalSince(start))
        guard elapsed < 14400 else {
            clearPersistedSession()
            return
        }

        workoutDayLabel = data["workoutDayLabel"] as? String ?? ""
        workoutName = data["workoutName"] as? String ?? ""
        workoutIcon = data["workoutIcon"] as? String ?? ""
        workoutFocusAreas = data["workoutFocusAreas"] as? [String] ?? []
        workoutIsWeakPointFocus = data["workoutIsWeakPointFocus"] as? Bool ?? false
        exerciseIds = data["exerciseIds"] as? [String] ?? []
        exerciseNames = data["exerciseNames"] as? [String] ?? []
        completedExerciseIds = Set(data["completedExerciseIds"] as? [String] ?? [])
        startTime = start
        elapsedSeconds = elapsed
        earnedPRPoints = data["earnedPRPoints"] as? Int ?? 0
        exercisePRs = Set(data["exercisePRIds"] as? [String] ?? [])
        prExerciseNames = data["prExerciseNames"] as? [String] ?? []
        currentExerciseName = data["currentExerciseName"] as? String ?? ""
        isActive = true

        startTimer()
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutActivityAttributes(workoutDayLabel: workoutDayLabel)
        let state = WorkoutActivityAttributes.ContentState(
            workoutName: workoutName,
            workoutIcon: workoutIcon,
            startTime: startTime ?? Date(),
            exercisesCompleted: completedCount,
            totalExercises: totalExercises,
            currentExerciseName: currentExerciseName,
            restSecondsRemaining: 0,
            isResting: false
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Live Activity not available
        }
    }

    func updateLiveActivity() {
        guard let activity else { return }

        let state = WorkoutActivityAttributes.ContentState(
            workoutName: workoutName,
            workoutIcon: workoutIcon,
            startTime: startTime ?? Date(),
            exercisesCompleted: completedCount,
            totalExercises: totalExercises,
            currentExerciseName: currentExerciseName,
            restSecondsRemaining: restSecondsRemaining,
            isResting: isResting
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            workoutName: workoutName,
            workoutIcon: workoutIcon,
            startTime: startTime ?? Date(),
            exercisesCompleted: completedCount,
            totalExercises: totalExercises,
            currentExerciseName: "",
            restSecondsRemaining: 0,
            isResting: false
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .default)
        }
        self.activity = nil
    }
}
