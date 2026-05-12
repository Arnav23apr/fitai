import Foundation

/// Weekly "ready to progress?" output from the AI coach. Generated server-
/// side by `ProgressionService` once per week per Pro user; surfaced as a
/// suggestion card on PlanView. The user can Apply (commits the changes
/// to their routines via RoutineService) or Keep current (dismisses for
/// the week).
///
/// Hybrid model (Option C from the design pass): AI only proposes when it
/// has confident evidence the user crushed the current plan. If the
/// `changes` array is empty, the suggestion isn't rendered — no nag.
nonisolated struct ProgressionSuggestion: Codable, Identifiable, Sendable {
    let id: String
    let generatedAt: Date
    /// Short headline shown on the suggestion card ("Ready for week 4?").
    /// Plain text, AI-authored. Keep under ~40 chars in the prompt.
    let headline: String
    /// One-line explanation of *why* the AI thinks progression is due
    /// ("You hit target reps on 5 of 6 sessions last week"). Shown on
    /// the card under the headline. AI-authored.
    let summary: String
    let changes: [ExerciseChange]

    init(
        id: String = UUID().uuidString,
        generatedAt: Date = Date(),
        headline: String,
        summary: String,
        changes: [ExerciseChange]
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.headline = headline
        self.summary = summary
        self.changes = changes
    }
}

/// One concrete change the AI is proposing on one exercise in one routine.
/// The user can apply the whole bundle, not individual lines (keeps the
/// UI simple). Apply logic translates this into a routine update.
nonisolated struct ExerciseChange: Codable, Identifiable, Sendable {
    let id: String
    /// Lowercased exercise name match key. Apply logic searches every
    /// routine for an exercise whose name lowercases to this.
    let exerciseName: String
    /// Display label for the change ("Bumped reps to 6-8").
    let label: String
    /// AI's reasoning ("You hit 12 reps on every set last week"). Used
    /// by an optional "See diff" pass; not shown on the compact card.
    let reason: String
    /// Numeric fields are optional so the AI can return only the dimension
    /// it wants to change. Apply logic skips fields that are nil.
    let newReps: String?
    let newSets: Int?

    init(
        id: String = UUID().uuidString,
        exerciseName: String,
        label: String,
        reason: String,
        newReps: String? = nil,
        newSets: Int? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.label = label
        self.reason = reason
        self.newReps = newReps
        self.newSets = newSets
    }
}
