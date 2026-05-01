import Testing
import Foundation
@testable import FitAI

@Suite(.serialized)
struct ExerciseLogServiceTests {

    private let key = "exerciseLogs"

    init() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("saveLog persists; loadAll returns it")
    func saveAndLoad() {
        let svc = ExerciseLogService.shared
        let log = ExerciseLog(
            exerciseName: "Bench Press",
            muscleGroup: "Chest",
            sets: [SetLog(weight: 100, reps: 5, isCompleted: true)],
            totalVolume: 500
        )
        svc.saveLog(log)
        let all = svc.loadAll()
        #expect(all.count == 1)
        #expect(all.first?.exerciseName == "Bench Press")
        #expect(all.first?.sets.first?.weight == 100)
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("replaceAll overwrites existing logs")
    func replaceAllOverwrites() {
        let svc = ExerciseLogService.shared
        svc.saveLog(ExerciseLog(exerciseName: "A", muscleGroup: "X", sets: []))
        svc.saveLog(ExerciseLog(exerciseName: "B", muscleGroup: "X", sets: []))
        #expect(svc.loadAll().count == 2)

        svc.replaceAll([ExerciseLog(exerciseName: "C", muscleGroup: "Y", sets: [])])
        let all = svc.loadAll()
        #expect(all.count == 1)
        #expect(all.first?.exerciseName == "C")
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("updateLog rewrites the matching id only")
    func updateLogMatchesById() {
        let svc = ExerciseLogService.shared
        let original = ExerciseLog(
            exerciseName: "Squat",
            muscleGroup: "Legs",
            sets: [SetLog(weight: 80, reps: 5, isCompleted: true)],
            totalVolume: 400
        )
        svc.saveLog(original)
        svc.saveLog(ExerciseLog(exerciseName: "Other", muscleGroup: "Z", sets: []))

        var updated = original
        updated.sets = [SetLog(weight: 100, reps: 5, isCompleted: true)]
        updated.totalVolume = 500
        svc.updateLog(updated)

        let all = svc.loadAll()
        #expect(all.count == 2)
        let restored = all.first(where: { $0.id == original.id })
        #expect(restored?.sets.first?.weight == 100)
        #expect(restored?.totalVolume == 500)
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("updateLog with unknown id is a no-op")
    func updateLogUnknownId() {
        let svc = ExerciseLogService.shared
        svc.saveLog(ExerciseLog(exerciseName: "Squat", muscleGroup: "Legs", sets: []))
        let countBefore = svc.loadAll().count

        let phantom = ExerciseLog(id: "does-not-exist", exerciseName: "Phantom", muscleGroup: "X", sets: [])
        svc.updateLog(phantom)

        let all = svc.loadAll()
        #expect(all.count == countBefore)
        #expect(all.allSatisfy { $0.exerciseName != "Phantom" })
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test("history filters by exercise name")
    func historyFiltersByName() {
        let svc = ExerciseLogService.shared
        svc.saveLog(ExerciseLog(exerciseName: "Squat", muscleGroup: "Legs", sets: [SetLog(weight: 100, reps: 5, isCompleted: true)], totalVolume: 500))
        svc.saveLog(ExerciseLog(exerciseName: "Bench", muscleGroup: "Chest", sets: [SetLog(weight: 80, reps: 5, isCompleted: true)], totalVolume: 400))

        let h = svc.history(for: "Squat")
        #expect(h.logs.count == 1)
        #expect(h.logs.first?.exerciseName == "Squat")
        UserDefaults.standard.removeObject(forKey: key)
    }
}
