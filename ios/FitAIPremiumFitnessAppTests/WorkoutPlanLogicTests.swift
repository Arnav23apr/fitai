import Testing
@testable import FitAI

struct WorkoutPlanLogicTests {

    @Test("BodyweightDetector recognizes common bodyweight movements")
    func bodyweightDetectorPositiveCases() {
        #expect(BodyweightDetector.isBodyweightExercise("Push-Ups"))
        #expect(BodyweightDetector.isBodyweightExercise("Pull up"))
        #expect(BodyweightDetector.isBodyweightExercise("Walking Lunges"))
        #expect(BodyweightDetector.isBodyweightExercise("Side Plank"))
        #expect(BodyweightDetector.isBodyweightExercise("Burpees"))
    }

    @Test("BodyweightDetector recognizes equipment-only movements")
    func bodyweightDetectorEquipmentCases() {
        #expect(BodyweightDetector.isEquipmentOnly("Barbell Bench Press"))
        #expect(BodyweightDetector.isEquipmentOnly("Lat Pulldown"))
        #expect(BodyweightDetector.isEquipmentOnly("Cable Row"))
        #expect(BodyweightDetector.isEquipmentOnly("Dumbbell Shoulder Press"))
    }

    @Test("BodyweightDetector does not mark equipment-only movements as bodyweight")
    func bodyweightDetectorNegativeCases() {
        #expect(!BodyweightDetector.isBodyweightExercise("Barbell Bench Press"))
        #expect(!BodyweightDetector.isBodyweightExercise("Leg Press"))
        #expect(!BodyweightDetector.isBodyweightExercise("Cable Flyes"))
    }

    @Test("Exercise tracking mode handles weighted, bodyweight, timed, and reps-only cases")
    func exerciseTrackingModes() {
        let weighted = Exercise(name: "Barbell Bench Press", sets: 3, reps: "8-10", muscleGroup: "Chest")
        let bodyweight = Exercise(name: "Walking Lunges", sets: 3, reps: "12/side", muscleGroup: "Legs")
        let timedByReps = Exercise(name: "Jump Rope", sets: 3, reps: "60s", muscleGroup: "Cardio")
        let timedByGroup = Exercise(name: "Easy Walk", sets: 1, reps: "10", muscleGroup: "Cardio")
        let repsOnlyMobility = Exercise(name: "Cat-Cow Stretch", sets: 2, reps: "10", muscleGroup: "Mobility")

        #expect(weighted.trackingMode == .weighted)
        #expect(bodyweight.trackingMode == .bodyweight)
        #expect(timedByReps.trackingMode == .timed)
        #expect(timedByGroup.trackingMode == .timed)
        #expect(repsOnlyMobility.trackingMode == .repsOnly)
    }

    @Test("Timed exercise duration parsing supports minutes, seconds, and side notation")
    func timedDurationParsing() {
        #expect(Exercise(name: "Walk", sets: 1, reps: "10min", muscleGroup: "Cardio").targetDurationSeconds == 600)
        #expect(Exercise(name: "Plank", sets: 3, reps: "90sec", muscleGroup: "Core").targetDurationSeconds == 90)
        #expect(Exercise(name: "Side Plank", sets: 3, reps: "60s/side", muscleGroup: "Core").targetDurationSeconds == 60)
        #expect(Exercise(name: "Bench", sets: 3, reps: "8-10", muscleGroup: "Chest").targetDurationSeconds == 0)
    }

    @Test("Walking lunge override stays bodyweight instead of timed")
    func walkingLungeOverride() {
        let exercise = Exercise(name: "Walking Lunges", sets: 3, reps: "12", muscleGroup: "Legs")
        #expect(exercise.trackingMode == .bodyweight)
    }

    @Test("Always-timed overrides handle numeric reps strings")
    func alwaysTimedOverrides() {
        #expect(Exercise(name: "Plank", sets: 3, reps: "30", muscleGroup: "Core").trackingMode == .timed)
        #expect(Exercise(name: "Wall Sit", sets: 3, reps: "45", muscleGroup: "Legs").trackingMode == .timed)
        #expect(Exercise(name: "Dead Hang", sets: 3, reps: "20", muscleGroup: "Back").trackingMode == .timed)
    }
}
