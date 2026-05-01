import Testing
import Foundation
@testable import FitAI

@Suite(.serialized)
@MainActor
struct WorkoutSessionManagerTests {

    init() {
        // Singleton: clear any leftover state between tests.
        WorkoutSessionManager.shared.endSession()
        UserDefaults.standard.removeObject(forKey: "activeWorkoutSession")
    }

    @Test func startWorkoutPopulatesState() {
        let m = WorkoutSessionManager.shared
        let workout = WorkoutDay(
            dayLabel: "MON",
            name: "Push Day",
            focusAreas: ["Chest"],
            icon: "dumbbell.fill",
            exercises: [
                Exercise(name: "Bench Press", sets: 3, reps: "8-10", muscleGroup: "Chest"),
                Exercise(name: "OHP", sets: 3, reps: "5", muscleGroup: "Shoulders"),
            ]
        )
        m.startWorkout(workout: workout)

        #expect(m.isActive)
        #expect(m.workoutName == "Push Day")
        #expect(m.exerciseIds.count == 2)
        #expect(m.completedExerciseIds.isEmpty)
        m.endSession()
    }

    @Test func beginPendingFinishPausesTimer() {
        let m = WorkoutSessionManager.shared
        let workout = WorkoutDay(
            dayLabel: "MON",
            name: "Push Day",
            focusAreas: ["Chest"],
            icon: "dumbbell.fill",
            exercises: [Exercise(name: "Bench", sets: 3, reps: "5", muscleGroup: "Chest")]
        )
        m.startWorkout(workout: workout)
        #expect(m.isActive)
        #expect(!m.isPendingFinish)

        m.beginPendingFinish()
        #expect(m.isPendingFinish)
        #expect(m.isActive)  // still active until commit
        m.endSession()
    }

    @Test func cancelPendingFinishKeepsSessionAlive() {
        let m = WorkoutSessionManager.shared
        let workout = WorkoutDay(
            dayLabel: "MON",
            name: "Push Day",
            focusAreas: ["Chest"],
            icon: "dumbbell.fill",
            exercises: [Exercise(name: "Bench", sets: 3, reps: "5", muscleGroup: "Chest")]
        )
        m.startWorkout(workout: workout)
        m.beginPendingFinish()
        m.cancelPendingFinish()

        #expect(!m.isPendingFinish)
        #expect(m.isActive)
        #expect(m.workoutName == "Push Day")
        m.endSession()
    }

    @Test func endSessionClearsPendingFlag() {
        let m = WorkoutSessionManager.shared
        let workout = WorkoutDay(
            dayLabel: "MON",
            name: "Push",
            focusAreas: ["Chest"],
            icon: "dumbbell.fill",
            exercises: [Exercise(name: "Bench", sets: 3, reps: "5", muscleGroup: "Chest")]
        )
        m.startWorkout(workout: workout)
        m.beginPendingFinish()
        m.endSession()

        #expect(!m.isActive)
        #expect(!m.isPendingFinish)
    }

    @Test func markExerciseCompletedAdvancesCurrent() {
        let m = WorkoutSessionManager.shared
        let e1 = Exercise(name: "Bench", sets: 3, reps: "5", muscleGroup: "Chest")
        let e2 = Exercise(name: "OHP", sets: 3, reps: "5", muscleGroup: "Shoulders")
        let workout = WorkoutDay(
            dayLabel: "MON",
            name: "Push",
            focusAreas: ["Chest"],
            icon: "dumbbell.fill",
            exercises: [e1, e2]
        )
        m.startWorkout(workout: workout)
        #expect(m.currentExerciseName == "Bench")

        m.markExerciseCompleted(e1.id, exerciseName: e1.name, volume: 500, hitPR: false)
        #expect(m.currentExerciseName == "OHP")
        #expect(m.completedCount == 1)

        m.markExerciseCompleted(e2.id, exerciseName: e2.name, volume: 300, hitPR: true)
        #expect(m.allCompleted)
        #expect(m.earnedPRPoints == 50)
        m.endSession()
    }
}
