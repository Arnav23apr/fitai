import SwiftUI
import UIKit

/// Confirmation flow after a photo capture. Shows what the AI saw, lets
/// the user confirm or correct exercise + weight, and asks for reps with
/// either a predicted default (from `UserPatternsService`) or a quick
/// voice prompt.
///
/// Returns the final `LoggedSet` to the host on Apply.
struct WeightOCRConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let capturedImage: UIImage
    let analysis: WeightOCRService.Result
    let onApply: (Apply) -> Void

    struct Apply {
        let exercise: String
        let weight: Double
        let reps: Int
        let unit: String
    }

    @State private var exerciseChoice: String = ""
    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @State private var predictedReps: Int? = nil
    @State private var showVoicePrompt: Bool = false
    @State private var ambiguousResolved: Bool = false

    private var unit: String { analysis.unit }

    private var needsExerciseChoice: Bool {
        analysis.exercise == nil ||
        analysis.exerciseConfidence < 0.85 ||
        !analysis.exerciseAlternatives.isEmpty
    }

    private var canApply: Bool {
        !exerciseChoice.isEmpty && weight > 0 && reps > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    capturedImageView
                    detectedSummary
                    if needsExerciseChoice && !ambiguousResolved {
                        exerciseChooser
                    } else {
                        weightCard
                        repsCard
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retake") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        commit()
                    }
                    .fontWeight(.bold)
                    .disabled(!canApply)
                }
            }
            .sheet(isPresented: $showVoicePrompt) {
                VoiceLogSheet { intent in
                    if case .logSet(let log) = intent {
                        if let r = log.reps as Int?, r > 0 { reps = r }
                        if let w = log.weight, w > 0 { weight = w }
                    }
                }
            }
        }
        .onAppear { primeDefaults() }
    }

    // MARK: - Subviews

    private var capturedImageView: some View {
        Image(uiImage: capturedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 220)
            .clipShape(.rect(cornerRadius: 16))
    }

    private var detectedSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: kindIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(.purple)
                Text(kindLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            if let plate = analysis.plateBreakdown {
                Text(plateBreakdownText(plate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var kindIcon: String {
        switch analysis.detectedKind {
        case .selectorPin: return "pin.fill"
        case .sticker: return "tag.fill"
        case .ledDisplay: return "display"
        case .loadedBarbell: return "dumbbell.fill"
        case .dial: return "dial.high"
        case .unclear: return "questionmark.circle.fill"
        }
    }

    private var kindLabel: String {
        switch analysis.detectedKind {
        case .selectorPin: return "Weight stack"
        case .sticker: return "Sticker / label"
        case .ledDisplay: return "Digital display"
        case .loadedBarbell: return "Loaded barbell"
        case .dial: return "Dial / engraving"
        case .unclear: return "Couldn't fully read"
        }
    }

    private func plateBreakdownText(_ plate: WeightOCRService.Result.PlateBreakdown) -> String {
        let plateBits = plate.perSidePlates
            .map { "\($0.count)× \(formatWeight($0.weight))" }
            .joined(separator: " + ")
        return "Per side: \(plateBits)  ·  Bar: \(formatWeight(plate.barWeight))"
    }

    /// Exercise picker — shown when AI is uncertain or has alternatives.
    private var exerciseChooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Which exercise?")
                .font(.headline)
            let candidates: [String] = {
                var list: [String] = []
                if let primary = analysis.exercise { list.append(primary) }
                list.append(contentsOf: analysis.exerciseAlternatives)
                // Add favorites for the muscle group as backup options.
                let favorites = UserPatternsService.shared.favoriteExercises(muscleGroup: "", limit: 3)
                for f in favorites where !list.contains(f) { list.append(f) }
                return list
            }()
            ForEach(candidates, id: \.self) { name in
                Button {
                    exerciseChoice = name
                    ambiguousResolved = true
                    refreshRepsPrediction()
                } label: {
                    HStack {
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Button {
                // Free-text fallback — user types/picks via the existing
                // exercise picker. For now, stamp with "Custom" and let
                // them fix it in the active session.
                exerciseChoice = "Custom Exercise"
                ambiguousResolved = true
                refreshRepsPrediction()
            } label: {
                Text("None of these. Pick another")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Weight")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatWeight(weight)) \(unit)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 10) {
                stepperButton(label: "−5") { weight = max(0, weight - 5) }
                stepperButton(label: "−2.5") { weight = max(0, weight - 2.5) }
                stepperButton(label: "+2.5") { weight += 2.5 }
                stepperButton(label: "+5") { weight += 5 }
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var repsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reps")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(reps)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            if let pred = predictedReps, pred != reps {
                Button {
                    reps = pred
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                        Text("Last time at \(formatWeight(weight)) \(unit): \(pred) reps. Use this?")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.purple)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 10) {
                stepperButton(label: "−1") { reps = max(0, reps - 1) }
                stepperButton(label: "+1") { reps += 1 }
                Spacer()
                Button {
                    showVoicePrompt = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11))
                        Text("Speak")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [.red, .red.opacity(0.85)],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func stepperButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 36)
                .background(Color.primary.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func primeDefaults() {
        if let detected = analysis.exercise, !needsExerciseChoice {
            exerciseChoice = detected
        }
        weight = analysis.weight ?? 0
        refreshRepsPrediction()
    }

    private func refreshRepsPrediction() {
        guard !exerciseChoice.isEmpty, weight > 0 else { return }
        let pred = UserPatternsService.shared.expectedReps(
            exercise: exerciseChoice,
            weight: weight,
            setIndex: 0
        )
        predictedReps = pred
        if reps == 0, let pred {
            reps = pred
        }
    }

    private func commit() {
        guard canApply else { return }
        _ = FreeUsageTracker.shared.record(.photo, isPremium: appState.profile.isPremium)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onApply(.init(exercise: exerciseChoice, weight: weight, reps: reps, unit: unit))
        dismiss()
    }

    private func formatWeight(_ value: Double) -> String {
        if value == value.rounded() { return "\(Int(value))" }
        return String(format: "%.1f", value)
    }
}
