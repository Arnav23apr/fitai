import Foundation
import Testing
@testable import FitAI

struct ExerciseHistoryTests {

    @Test("ExerciseLog computed metrics ignore incomplete sets")
    func exerciseLogComputedMetrics() {
        let log = ExerciseLog(
            exerciseName: "Bench Press",
            muscleGroup: "Chest",
            sets: [
                SetLog(weight: 100, reps: 5, isCompleted: true),
                SetLog(weight: 110, reps: 3, isCompleted: false),
                SetLog(weight: 90, reps: 8, isCompleted: true),
            ]
        )

        #expect(log.computedVolume == 1220)
        #expect(log.bestSetWeight == 100)
        #expect(log.bestSetReps == 8)
    }

    @Test("ExerciseHistory personal bests span all completed sets")
    func exerciseHistoryPersonalBests() {
        let older = ExerciseLog(
            exerciseName: "Squat",
            muscleGroup: "Legs",
            date: Date(timeIntervalSince1970: 100),
            sets: [
                SetLog(weight: 120, reps: 5, isCompleted: true),
                SetLog(weight: 130, reps: 3, isCompleted: false),
            ]
        )
        let newer = ExerciseLog(
            exerciseName: "Squat",
            muscleGroup: "Legs",
            date: Date(timeIntervalSince1970: 200),
            sets: [
                SetLog(weight: 115, reps: 8, isCompleted: true),
            ]
        )

        let history = ExerciseHistory(exerciseName: "Squat", logs: [older, newer])

        #expect(history.personalBestWeight == 120)
        #expect(history.personalBestReps == 8)
        #expect(history.personalBestVolume == 920)
        #expect(history.lastSession?.id == newer.id)
    }

    @Test("ExerciseHistory volume trend detects up, down, and neutral")
    func exerciseHistoryVolumeTrend() {
        let low = ExerciseLog(
            exerciseName: "Row",
            muscleGroup: "Back",
            date: Date(timeIntervalSince1970: 100),
            sets: [SetLog(weight: 100, reps: 5, isCompleted: true)]
        )
        let high = ExerciseLog(
            exerciseName: "Row",
            muscleGroup: "Back",
            date: Date(timeIntervalSince1970: 200),
            sets: [SetLog(weight: 120, reps: 5, isCompleted: true)]
        )
        let laterLow = ExerciseLog(
            exerciseName: "Row",
            muscleGroup: "Back",
            date: Date(timeIntervalSince1970: 300),
            sets: [SetLog(weight: 100, reps: 5, isCompleted: true)]
        )
        let similar = ExerciseLog(
            exerciseName: "Row",
            muscleGroup: "Back",
            date: Date(timeIntervalSince1970: 400),
            sets: [SetLog(weight: 123, reps: 5, isCompleted: true)]
        )

        #expect(ExerciseHistory(exerciseName: "Row", logs: [low, high]).volumeTrend == .up)
        #expect(ExerciseHistory(exerciseName: "Row", logs: [high, laterLow]).volumeTrend == .down)
        #expect(ExerciseHistory(exerciseName: "Row", logs: [high, similar]).volumeTrend == .neutral)
    }

    @Test("ExerciseHistory PR readiness only flags near-best recent sessions")
    func exerciseHistoryPrReadiness() {
        let best = ExerciseLog(
            exerciseName: "Bench",
            muscleGroup: "Chest",
            date: Date(timeIntervalSince1970: 100),
            sets: [SetLog(weight: 100, reps: 5, isCompleted: true)]
        )
        let nearBest = ExerciseLog(
            exerciseName: "Bench",
            muscleGroup: "Chest",
            date: Date(timeIntervalSince1970: 200),
            sets: [SetLog(weight: 95, reps: 5, isCompleted: true)]
        )
        let matchedBest = ExerciseLog(
            exerciseName: "Bench",
            muscleGroup: "Chest",
            date: Date(timeIntervalSince1970: 300),
            sets: [SetLog(weight: 100, reps: 5, isCompleted: true)]
        )

        #expect(ExerciseHistory(exerciseName: "Bench", logs: [best, nearBest]).isPRReady)
        #expect(!ExerciseHistory(exerciseName: "Bench", logs: [best, matchedBest]).isPRReady)
    }
}
