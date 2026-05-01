import Testing
@testable import FitAI

struct ExerciseDatabaseTests {

    @Test("Exact name lookup hits known entry")
    func exactLookup() {
        let info = ExerciseDatabase.shared.info(for: "Barbell Bench Press")
        #expect(info.name == "Barbell Bench Press")
        #expect(!info.instructions.isEmpty)
        #expect(info.primaryMuscles.contains("Chest"))
    }

    @Test("Lookup is case-insensitive")
    func caseInsensitive() {
        let info = ExerciseDatabase.shared.info(for: "barbell bench press")
        #expect(info.name == "Barbell Bench Press")
        #expect(!info.instructions.isEmpty)
    }

    @Test("Unknown exercise returns generic fallback")
    func unknownFallback() {
        let info = ExerciseDatabase.shared.info(for: "Made Up Movement")
        #expect(info.name == "Made Up Movement")
        #expect(!info.instructions.isEmpty)  // generic fallback present
        #expect(info.primaryMuscles.isEmpty)  // no muscles for unknown
    }
}
