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
    /// Full Exercise objects for the in-progress workout — kept so Resume
    /// rebuilds the *actual* started workout (correct sets/reps/muscleGroup),
    /// not today's scheduled plan, which can differ if the user started a
    /// different day or the plan regenerated.
    var exercises: [Exercise] = []
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
    /// Timestamp when the current rest period ends (nil = not resting).
    /// Pushed to the Live Activity so iOS can keep the lock-screen
    /// countdown ticking without the app being awake. The legacy
    /// `restSecondsRemaining` is still maintained for the in-app UI
    /// timer shown in `SetLoggingSheet` (foreground only).
    var restEndsAt: Date? = nil
    /// True after the user taps Finish but before commit lands (8s undo window).
    /// While true the session data is preserved so the user can revert.
    var isPendingFinish: Bool = false

    private var timer: Timer?
    private var activity: Activity<WorkoutActivityAttributes>?

    private init() {
        restoreSession()
    }

    var totalExercises: Int { exerciseIds.count }
    var completedCount: Int { completedExerciseIds.count }
    var allCompleted: Bool { completedExerciseIds.count == exerciseIds.count && !exerciseIds.isEmpty }

    /// Strong-style "Start Empty Workout". No exercises pre-loaded — the user
    /// adds them as they go. Title auto-generated from time-of-day so the
    /// session feels distinct in History.
    func startEmptyWorkout() {
        let day = WorkoutDay(
            dayLabel: "EMPTY",
            name: Self.timeOfDayWorkoutName(),
            focusAreas: [],
            icon: "dumbbell.fill",
            isRestDay: false,
            exercises: [],
            isWeakPointFocus: false
        )
        startWorkout(workout: day)
    }

    /// Append an exercise to the in-progress session. Used by Strong's
    /// "Add Exercises" button and the Coach's plan-mod tool.
    func appendExercise(_ exercise: Exercise) {
        guard isActive else { return }
        exercises.append(exercise)
        exerciseIds.append(exercise.id)
        exerciseNames.append(exercise.name)
        if currentExerciseName.isEmpty {
            currentExerciseName = exercise.name
        }
        persistSession()
        updateLiveActivity()
    }

    /// Swap an exercise in place. Preserves position so the lifter
    /// keeps the order they set up. Mirrors the SessionExercise replace
    /// in ActiveSessionView so persistence + Live Activity stay in sync.
    func replaceExercise(id: String, with replacement: Exercise) {
        guard isActive else { return }
        guard let idx = exercises.firstIndex(where: { $0.id == id }) else { return }
        let oldName = exercises[idx].name
        exercises[idx] = replacement
        if let nameIdx = exerciseIds.firstIndex(of: id) {
            exerciseNames[nameIdx] = replacement.name
        }
        if currentExerciseName == oldName || currentExerciseName.isEmpty {
            currentExerciseName = replacement.name
        }
        persistSession()
        updateLiveActivity()
    }

    /// Remove an exercise from the in-progress session.
    func removeExercise(id: String) {
        guard isActive else { return }
        exercises.removeAll { $0.id == id }
        exerciseIds.removeAll { $0 == id }
        if let firstId = exerciseIds.first(where: { !completedExerciseIds.contains($0) }),
           let ex = exercises.first(where: { $0.id == firstId }) {
            currentExerciseName = ex.name
        } else if exerciseIds.isEmpty {
            currentExerciseName = ""
        }
        completedExerciseIds.remove(id)
        persistSession()
        updateLiveActivity()
    }

    /// "Good Morning Workout", "Lunch Workout", "Afternoon Workout", "Evening
    /// Workout", "Midnight Workout" — matches Strong's auto-naming.
    static func timeOfDayWorkoutName() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Morning Workout"
        case 11..<14: return "Lunch Workout"
        case 14..<17: return "Afternoon Workout"
        case 17..<21: return "Evening Workout"
        default: return "Midnight Workout"
        }
    }

    func startWorkout(workout: WorkoutDay) {
        isActive = true
        workoutDayLabel = workout.dayLabel
        workoutName = workout.name
        workoutIcon = workout.icon
        workoutFocusAreas = workout.focusAreas
        workoutIsWeakPointFocus = workout.isWeakPointFocus
        exercises = workout.exercises
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
            // Surface to friends' activity feed.
            Task.detached {
                await SocialService.shared.postActivity(
                    kind: "pr_set",
                    payload: ["exercise": exerciseName]
                )
            }
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
        // Only update the Live Activity (and recompute restEndsAt) on
        // *transitions* — start of rest, end of rest. Per-second updates
        // are unnecessary because the widget renders an OS-driven
        // `Text(timerInterval:)` from the future Date we set here.
        let nowResting = isResting && secondsRemaining > 0
        let wasResting = self.restEndsAt != nil
        if nowResting && !wasResting {
            self.restEndsAt = Date().addingTimeInterval(TimeInterval(secondsRemaining))
            updateLiveActivity()
        } else if !nowResting && wasResting {
            self.restEndsAt = nil
            updateLiveActivity()
        }
        // Same-rest mid-tick: skip the activity push. The widget keeps
        // counting down on its own.
    }

    func endSession() {
        isActive = false
        isPendingFinish = false
        timer?.invalidate()
        timer = nil
        exercises = []
        clearPersistedSession()
        endLiveActivity()
    }

    /// Rebuild the in-progress WorkoutDay from session state so Resume opens
    /// the workout the user actually started, not whatever's scheduled today.
    func resumedWorkoutDay() -> WorkoutDay {
        WorkoutDay(
            dayLabel: workoutDayLabel,
            name: workoutName,
            focusAreas: workoutFocusAreas,
            icon: workoutIcon,
            isRestDay: false,
            exercises: exercises,
            isWeakPointFocus: workoutIsWeakPointFocus
        )
    }

    /// Enter the undo-grace-period: timer pauses, state preserved, Live Activity
    /// kept around. Commit by calling `endSession()`; revert with `cancelPendingFinish()`.
    func beginPendingFinish() {
        isPendingFinish = true
        timer?.invalidate()
        timer = nil
    }

    /// Roll back from a grace period: resume the timer, leave session active.
    func cancelPendingFinish() {
        guard isPendingFinish else { return }
        isPendingFinish = false
        if isActive { startTimer() }
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
        let exercisePayload: [[String: Any]] = exercises.map { ex in
            [
                "id": ex.id,
                "name": ex.name,
                "sets": ex.sets,
                "reps": ex.reps,
                "muscleGroup": ex.muscleGroup,
                "suggestedWeights": ex.suggestedWeights,
                "suggestedReps": ex.suggestedReps
            ]
        }
        let data: [String: Any] = [
            "workoutDayLabel": workoutDayLabel,
            "workoutName": workoutName,
            "workoutIcon": workoutIcon,
            "workoutFocusAreas": workoutFocusAreas,
            "workoutIsWeakPointFocus": workoutIsWeakPointFocus,
            "exercises": exercisePayload,
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
        if let payload = data["exercises"] as? [[String: Any]] {
            exercises = payload.compactMap { dict in
                guard
                    let id = dict["id"] as? String,
                    let name = dict["name"] as? String,
                    let sets = dict["sets"] as? Int,
                    let reps = dict["reps"] as? String,
                    let muscleGroup = dict["muscleGroup"] as? String
                else { return nil }
                return Exercise(
                    id: id,
                    name: name,
                    sets: sets,
                    reps: reps,
                    muscleGroup: muscleGroup,
                    suggestedWeights: dict["suggestedWeights"] as? [Double] ?? [],
                    suggestedReps: dict["suggestedReps"] as? [Int] ?? []
                )
            }
        } else {
            exercises = zip(exerciseIds, exerciseNames).map { id, name in
                Exercise(id: id, name: name, sets: 3, reps: "8-12", muscleGroup: "")
            }
        }
        completedExerciseIds = Set(data["completedExerciseIds"] as? [String] ?? [])
        startTime = start
        elapsedSeconds = elapsed
        earnedPRPoints = data["earnedPRPoints"] as? Int ?? 0
        exercisePRs = Set(data["exercisePRIds"] as? [String] ?? [])
        prExerciseNames = data["prExerciseNames"] as? [String] ?? []
        currentExerciseName = data["currentExerciseName"] as? String ?? ""
        isActive = true

        startTimer()
        // After a crash mid-workout the in-memory `activity` reference is
        // gone but the Live Activity itself is still running on the lock
        // screen. Reattach so a later end/finish actually terminates it.
        reattachExistingActivity()
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    /// Public hook for `AppState.logout()` / `deleteAccount()` to wipe an
    /// in-flight session belonging to a previous user. Without this the
    /// next user signing in on the same device would inherit the prior
    /// user's "Resume workout" pill until they completed or discarded it.
    static func clearPersistedSessionForLogout() {
        UserDefaults.standard.removeObject(forKey: "activeWorkoutSession")
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("[LiveActivity] Activities not enabled by user")
            #endif
            return
        }

        let attributes = WorkoutActivityAttributes(workoutDayLabel: workoutDayLabel)
        let state = WorkoutActivityAttributes.ContentState(
            workoutName: workoutName,
            workoutIcon: workoutIcon,
            startTime: startTime ?? Date(),
            exercisesCompleted: completedCount,
            totalExercises: totalExercises,
            currentExerciseName: currentExerciseName,
            restEndsAt: nil
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            #if DEBUG
            print("[LiveActivity] Started successfully, id: \(activity?.id ?? "nil")")
            #endif
        } catch {
            #if DEBUG
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
            #endif
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
            restEndsAt: restEndsAt
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// End the workout Live Activity. Iterates ALL running workout
    /// activities (not just `self.activity`) because the captured reference
    /// can go stale after app suspension / re-launch / singleton edge cases
    /// — the previous version guarded on `self.activity` and silently
    /// no-op'd, which is why the activity didn't disappear when users
    /// finished. Dismissal is `.immediate` so the lock screen frees up the
    /// moment the user finishes; the prior 30s linger looked like a bug.
    private func endLiveActivity() {
        for active in Activity<WorkoutActivityAttributes>.activities {
            Task { await active.end(nil, dismissalPolicy: .immediate) }
        }
        self.activity = nil
    }

    /// Reattach the manager to whatever Live Activity is still running for
    /// this workout (if any). Called from restoreSession after a crash so
    /// `endLiveActivity` can find and end the activity later. Without this,
    /// post-crash workouts leave zombie activities on the lock screen.
    private func reattachExistingActivity() {
        if let existing = Activity<WorkoutActivityAttributes>.activities.first {
            activity = existing
        }
    }

    /// Force-end every running workout activity immediately. Use on
    /// sign-out / hard reset.
    static func endAllActivities() {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
