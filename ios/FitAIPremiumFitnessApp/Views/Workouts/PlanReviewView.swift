import SwiftUI

/// Path 3 — user pastes their existing workout plan in any format, Coach
/// parses it into templates and critiques it (strengths / weaknesses /
/// suggestions). User can save all templates with one tap.
///
/// Pro-gated. Free users see a paywall hand-off.
struct PlanReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let onComplete: () -> Void

    @State private var rawText: String = ""
    @State private var isLoading: Bool = false
    @State private var review: PlanModificationService.PlanReview? = nil
    @State private var errorMessage: String? = nil
    @State private var showPaywall: Bool = false
    @State private var showSavedToast: Bool = false

    private let service = PlanModificationService.shared

    private var isPro: Bool { appState.profile.isPremium }
    private var canGenerate: Bool {
        isPro && !isLoading && rawText.trimmingCharacters(in: .whitespacesAndNewlines).count > 10
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCopy
                    if !isPro {
                        proGateCard
                    }
                    pasteBox
                    generateButton
                    if let review {
                        if review.hasClarification, let clar = review.clarification {
                            clarificationCard(clar)
                        } else {
                            critiqueCard(review.critique)
                            templatesList(review.templates)
                            saveAllRow(review.templates)
                        }
                    }
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Review my plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { CurrentPlanSheet() }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    savedToast
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Header

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paste your current program")
                .font(.title3.weight(.bold))
            Text("Any format works — bullet points, paragraph, day-by-day. Coach will parse it, give honest feedback, and import it as templates you can use right away.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Pro gate

    private var proGateCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro feature")
                        .font(.caption.weight(.bold))
                    Text("Plan review is part of FitAI Pro")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.yellow.opacity(0.10))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Paste box

    private var pasteBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "e.g. Mon — Bench 4×8, Incline DB 3×10, OHP 4×8…",
                text: $rawText,
                axis: .vertical
            )
            .lineLimit(8...20)
            .padding(12)
            .background(Color.primary.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))
            .font(.system(size: 14))
            .disabled(!isPro)
            HStack {
                Spacer()
                Text("\(rawText.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var generateButton: some View {
        Button {
            Task { await runReview() }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .heavy))
                }
                Text(isLoading ? "Analyzing…" : "Review my plan")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(canGenerate ? Color.blue : Color.blue.opacity(0.4))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canGenerate)
    }

    // MARK: - Output

    private func critiqueCard(_ critique: PlanModificationService.PlanReview.Critique) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Coach's review")
                .font(.headline)
            critiqueGroup(title: "Strengths", icon: "checkmark.seal.fill", color: .green, items: critique.strengths)
            critiqueGroup(title: "Weak spots", icon: "exclamationmark.triangle.fill", color: .orange, items: critique.weaknesses)
            critiqueGroup(title: "Suggestions", icon: "wand.and.stars", color: .purple, items: critique.suggestions)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func critiqueGroup(title: String, icon: String, color: Color, items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundStyle(color)
                            .font(.caption)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(color.opacity(0.06))
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func templatesList(_ specs: [PlanModificationService.TemplateSpec]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Parsed templates")
                    .font(.headline)
                Text("\(specs.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            ForEach(specs) { spec in
                templateCard(spec)
            }
        }
    }

    private func templateCard(_ spec: PlanModificationService.TemplateSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.indigo.opacity(0.25), .purple.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    Image(systemName: spec.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(spec.name)
                        .font(.subheadline.weight(.bold))
                    Text("\(spec.exercises.count) exercises · \(spec.defaultRestSeconds)s rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(spec.exercises.map { "\($0.name) (\($0.sets)×\($0.reps))" }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if let reason = spec.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func saveAllRow(_ specs: [PlanModificationService.TemplateSpec]) -> some View {
        Button {
            saveAll(specs)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 13))
                Text(specs.count == 1 ? "Import Template" : "Import All (\(specs.count))")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func clarificationCard(_ clar: PlanModificationService.ClarificationRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundStyle(.purple)
                Text("Coach needs more info")
                    .font(.subheadline.weight(.bold))
            }
            ForEach(Array(clar.questions.enumerated()), id: \.offset) { _, q in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(.purple)
                        .padding(.top, 6)
                    Text(q)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(8)
                .background(Color.purple.opacity(0.06))
                .clipShape(.rect(cornerRadius: 8))
            }
            Text("Add the missing details to your plan above and run review again.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.purple.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Templates imported")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    // MARK: - Actions

    private func runReview() async {
        guard canGenerate else { return }
        isLoading = true
        errorMessage = nil
        review = nil
        do {
            let result = try await service.reviewPlan(rawText: rawText, profile: appState.profile)
            await MainActor.run {
                review = result
                isLoading = false
            }
        } catch let error as PlanModificationService.ModError {
            await MainActor.run {
                switch error {
                case .emptyResponse:
                    errorMessage = "Coach couldn't extract anything from that. Try formatting it day-by-day with exercises, sets, and reps."
                case .decode:
                    errorMessage = "Coach's response wasn't readable. Please try again."
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't reach the coach right now. Check your connection."
                isLoading = false
            }
        }
    }

    private func saveAll(_ specs: [PlanModificationService.TemplateSpec]) {
        var saved = 0
        for spec in specs {
            if RoutineService.shared.save(spec.toRoutine(), isPremium: isPro) {
                saved += 1
            }
        }
        if saved > 0 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Promote the user to "userPlanReviewed" mode so the hub
            // doesn't keep nagging them with the AI plan.
            appState.profile.workoutMode = .userPlanReviewed
            appState.saveProfile()
            withAnimation { showSavedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onComplete()
                dismiss()
            }
        }
    }
}
