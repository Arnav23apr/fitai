import Foundation

/// Encodes a `Routine` into a self-describing text payload so users can
/// share templates over any messaging surface (iMessage, WhatsApp, etc.)
/// without needing a custom URL scheme. Strong follows the same pattern
/// alongside its deep-link share so that a recipient without the app
/// still sees a readable workout description.
///
/// The payload format combines a human-readable header (the routine
/// name + each exercise as plain text) with a base64-encoded JSON blob
/// at the bottom, fenced by a magic delimiter:
///
///   ===== FitAI Template =====
///   📋 Push Day
///   1. Bench Press — 4×8
///   2. Overhead Press — 4×8
///   ...
///   --- import ---
///   <base64 JSON>
///   --------------
///
/// The user pastes this anywhere; the next time they open Templates and
/// hit "Import from clipboard," the magic delimiter is recognized and
/// the routine is materialized.
enum RoutineShareService {

    /// Magic delimiters used to spot a sharable template inside an
    /// arbitrary clipboard text. Stable across versions.
    static let importMarker = "--- fitai-import ---"
    static let endMarker = "--- end ---"

    /// Build the shareable text payload for a routine.
    static func makeShareText(_ routine: Routine) -> String {
        var lines: [String] = []
        lines.append("===== FitAI Template =====")
        lines.append("📋 \(routine.name)")
        for (idx, ex) in routine.exercises.enumerated() {
            lines.append("\(idx + 1). \(ex.name) — \(ex.sets)×\(ex.reps)")
        }
        lines.append("Default rest: \(routine.defaultRestSeconds)s")
        lines.append("")
        lines.append(importMarker)
        if let json = try? JSONEncoder().encode(SharePayload.from(routine)),
           let b64 = Optional(json.base64EncodedString()) {
            lines.append(b64)
        }
        lines.append(endMarker)
        return lines.joined(separator: "\n")
    }

    /// Try to decode an incoming clipboard string into a `Routine`.
    /// Returns nil if the marker isn't present or the payload doesn't
    /// decode. Caller (the import sheet) shows a "we couldn't read this"
    /// error in that case.
    static func decode(_ raw: String) -> Routine? {
        let lines = raw.components(separatedBy: .newlines)
        guard let startIdx = lines.firstIndex(of: importMarker),
              let endIdx = lines.firstIndex(of: endMarker),
              endIdx > startIdx + 1 else {
            return nil
        }
        let b64 = lines[(startIdx + 1)..<endIdx]
            .joined()
            .trimmingCharacters(in: .whitespaces)
        guard let data = Data(base64Encoded: b64),
              let payload = try? JSONDecoder().decode(SharePayload.self, from: data) else {
            return nil
        }
        return payload.toRoutine()
    }
}

/// Wire format for the encoded payload. Versioned so a future change can
/// be detected and migrated. Decoder is tolerant of missing fields.
private struct SharePayload: Codable {
    var version: Int
    var name: String
    var icon: String
    var defaultRestSeconds: Int
    var exercises: [SharedExercise]
    var folder: String?

    static func from(_ routine: Routine) -> SharePayload {
        SharePayload(
            version: 1,
            name: routine.name,
            icon: routine.icon,
            defaultRestSeconds: routine.defaultRestSeconds,
            exercises: routine.exercises.map(SharedExercise.from),
            folder: routine.folder
        )
    }

    func toRoutine() -> Routine {
        // Fresh ids on import so the same template can be imported into
        // multiple devices without colliding.
        Routine(
            name: name,
            icon: icon,
            exercises: exercises.map { $0.toRoutineExercise() },
            defaultRestSeconds: defaultRestSeconds,
            folder: folder
        )
    }
}

private struct SharedExercise: Codable {
    var name: String
    var sets: Int
    var reps: String
    var muscleGroup: String
    var notes: String?
    var supersetGroup: Int?
    var targetRPE: Int?
    var restSecondsOverride: Int?

    static func from(_ ex: RoutineExercise) -> SharedExercise {
        SharedExercise(
            name: ex.name,
            sets: ex.sets,
            reps: ex.reps,
            muscleGroup: ex.muscleGroup,
            notes: ex.notes.isEmpty ? nil : ex.notes,
            supersetGroup: ex.supersetGroup,
            targetRPE: ex.targetRPE,
            restSecondsOverride: ex.restSecondsOverride
        )
    }

    func toRoutineExercise() -> RoutineExercise {
        RoutineExercise(
            name: name,
            sets: sets,
            reps: reps,
            muscleGroup: muscleGroup,
            restSecondsOverride: restSecondsOverride,
            notes: notes ?? "",
            supersetGroup: supersetGroup,
            targetRPE: targetRPE
        )
    }
}
