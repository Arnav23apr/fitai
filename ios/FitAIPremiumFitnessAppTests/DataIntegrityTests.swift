import Foundation
import Testing
@testable import FitAI

struct DataIntegrityTests {

    @Test("Bundled exercises JSON decodes and has required fields")
    func bundledExercisesDecode() throws {
        let exercises = try loadBundledExercises()

        #expect(exercises.count > 500)
        #expect(Set(exercises.map(\.id)).count == exercises.count)
        #expect(exercises.allSatisfy { !$0.id.isEmpty })
        #expect(exercises.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        #expect(exercises.allSatisfy { !$0.primaryMuscles.isEmpty })
        let exercisesWithCompleteInstructions = exercises.filter { exercise in
            !exercise.instructions.isEmpty &&
                exercise.instructions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        #expect(exercisesWithCompleteInstructions.count >= 850)
    }

    @Test("Exercise media manifest decodes and references usable remote image URLs")
    func exerciseMediaManifestDecodes() throws {
        let media = try loadMediaManifest()

        #expect(media.count > 20)
        #expect(media.keys.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        #expect(media.values.allSatisfy { entry in
            entry.video.isEmpty || isHTTPSURL(entry.video)
        })
        #expect(media.values.allSatisfy { entry in
            entry.thumb.isEmpty || isHTTPSURL(entry.thumb)
        })
        #expect(media.values.allSatisfy { entry in
            (entry.frames ?? []).allSatisfy(isHTTPSURL)
        })
        #expect(media.values.contains { !$0.thumb.isEmpty || !($0.frames ?? []).isEmpty })
    }

    @Test("Curated exercise database entries have instructions and media when manifest exists")
    func curatedExerciseDatabaseEntries() {
        let bench = ExerciseDatabase.shared.info(for: "Barbell Bench Press")
        let squat = ExerciseDatabase.shared.info(for: "Barbell Squat")
        let unknown = ExerciseDatabase.shared.info(for: "Definitely Not Real")

        #expect(bench.name == "Barbell Bench Press")
        #expect(bench.instructions.count >= 3)
        #expect(bench.primaryMuscles.contains("Chest"))
        #expect(bench.hasMedia)

        #expect(squat.name == "Barbell Squat")
        #expect(squat.instructions.count >= 3)
        #expect(squat.primaryMuscles.contains("Quads") || squat.primaryMuscles.contains("Quadriceps"))
        #expect(squat.hasMedia)

        #expect(unknown.name == "Definitely Not Real")
        #expect(!unknown.instructions.isEmpty)
        #expect(!unknown.hasMedia)
    }

    private func loadBundledExercises() throws -> [BundledExerciseFixture] {
        let url = try #require(Bundle.main.url(forResource: "exercises", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([BundledExerciseFixture].self, from: data)
    }

    private func loadMediaManifest() throws -> [String: ExerciseMediaFixture] {
        let url = try #require(Bundle.main.url(forResource: "exercise_media", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: ExerciseMediaFixture].self, from: data)
    }

    private func isHTTPSURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw) else { return false }
        return url.scheme == "https" && url.host != nil
    }
}

private struct BundledExerciseFixture: Decodable {
    let id: String
    let name: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
}

private struct ExerciseMediaFixture: Decodable {
    let video: String
    let thumb: String
    let frames: [String]?
}
