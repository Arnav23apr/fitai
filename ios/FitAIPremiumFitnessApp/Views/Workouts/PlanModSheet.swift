import SwiftUI

/// Chat-driven plan modification + creation sheet.
///
/// - Pass a `routine` to launch in MODIFY context — Coach proposes a diff
///   over the existing template, user reviews + applies.
/// - Pass `routine = nil` to launch in CREATE context — Coach generates one
///   or more brand-new templates from a free-text prompt.
///
/// In modify context, Coach may *still* return new templates instead of
/// edits if the prompt clearly asks for that ("make me 2 templates …") —
/// the UI just renders whatever came back.
struct PlanModSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// nil = create-only mode (no existing routine to edit).
    let routine: Routine?
    let onApplied: (Routine) -> Void

    @State private var prompt: String = ""
    @State private var isLoading: Bool = false
    @State private var response: PlanModificationService.GenerateResponse? = nil
    @State private var errorMessage: String? = nil
    @State private var showPaywall: Bool = false
    @State private var savedTemplateCount: Int = 0

    private let service = PlanModificationService.shared

    private var isPro: Bool { appState.profile.isPremium }

    private var navTitle: String {
        routine == nil ? "Create with Coach" : "Modify with Coach"
    }

    private var promptPlaceholder: String {
        routine == nil
            ? "e.g. Make me 2 templates: upper body and lower body, 6-7 reps each"
            : "e.g. Swap bench for incline DB and add face pulls"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !isPro {
                        proGateBanner
                    }
                    promptBox
                    if let response {
                        responseCard(response)
                    } else if let errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                CurrentPlanSheet()
            }
        }
    }

    // MARK: - Subviews

    private var proGateBanner: some View {
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
                        .foregroundStyle(.primary)
                    Text("Coach-driven template editing is part of FitAI Pro")
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

    private var promptBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What would you like \(routine == nil ? "to create" : "to change")?")
                .font(.headline)
            TextField(
                promptPlaceholder,
                text: $prompt,
                axis: .vertical
            )
            .lineLimit(3...6)
            .padding(12)
            .background(Color.primary.opacity(0.06))
            .clipShape(.rect(cornerRadius: 12))
            Button {
                Task { await generate() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                    }
                    Text(isLoading ? "Thinking…" : (routine == nil ? "Generate Templates" : "Generate Changes"))
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(canGenerate ? Color.blue : Color.blue.opacity(0.4))
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canGenerate)
        }
    }

    private var canGenerate: Bool {
        isPro && !isLoading && !prompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private func responseCard(_ response: PlanModificationService.GenerateResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !response.summary.isEmpty {
                Text(response.summary)
                    .font(.subheadline.weight(.semibold))
            }

            if response.hasClarification, let clar = response.clarification {
                clarificationCard(clar)
            } else if response.hasEdits {
                editsList(response.edits)
                editsActionRow(response.edits)
            } else if response.hasNewTemplates {
                newTemplatesList(response.newTemplates)
                newTemplatesActionRow(response.newTemplates)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    /// Coach asked follow-up questions. Render them as tappable rows that
    /// drop a quoted prompt into the input box, so the user can answer
    /// inline without retyping the original request.
    private func clarificationCard(_ clar: PlanModificationService.ClarificationRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
                Text("Coach needs a bit more info")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(clar.questions.enumerated()), id: \.offset) { _, question in
                    Button {
                        // Pre-fill the input with the original prompt + this
                        // question's framing, so the user just types the
                        // answer and re-submits.
                        prompt = "\(prompt)\n\nAnswer: \(question) "
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(.purple)
                                .padding(.top, 7)
                            Text(question)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(Color.purple.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Tap a question to add an answer slot, then submit again.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func editsList(_ edits: [PlanModificationService.EditOp]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(edits) { op in
                HStack(alignment: .top, spacing: 10) {
                    Text(opIcon(op.op))
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(op.humanReadable)
                            .font(.subheadline.weight(.semibold))
                        if let reason = op.reason, !reason.isEmpty {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .background(opTint(op.op).opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private func newTemplatesList(_ specs: [PlanModificationService.TemplateSpec]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(specs) { spec in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.25), .indigo.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 30, height: 30)
                            Image(systemName: spec.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.purple)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(spec.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
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
                .background(
                    LinearGradient(
                        colors: [.purple.opacity(0.06), .indigo.opacity(0.03), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.18), lineWidth: 0.6)
                )
            }
        }
    }

    private func editsActionRow(_ edits: [PlanModificationService.EditOp]) -> some View {
        HStack(spacing: 10) {
            Button {
                self.response = nil
            } label: {
                actionButtonLabel("Cancel", primary: false)
            }
            .buttonStyle(.plain)
            Button {
                applyEdits(edits)
            } label: {
                actionButtonLabel("Apply", primary: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func newTemplatesActionRow(_ specs: [PlanModificationService.TemplateSpec]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    self.response = nil
                } label: {
                    actionButtonLabel("Cancel", primary: false)
                }
                .buttonStyle(.plain)
                Button {
                    saveAllTemplates(specs)
                } label: {
                    actionButtonLabel(specs.count == 1 ? "Save Template" : "Save All (\(specs.count))", primary: true)
                }
                .buttonStyle(.plain)
                .disabled(atFreeCapForCount(specs.count))
            }
            if atFreeCapForCount(specs.count) {
                paywallNotice(needed: specs.count)
            }
        }
        .padding(.top, 4)
    }

    private func actionButtonLabel(_ text: String, primary: Bool) -> some View {
        Text(text)
            .font(.subheadline.weight(primary ? .bold : .semibold))
            .foregroundStyle(primary ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(primary ? Color.blue : Color.primary.opacity(0.06))
            .clipShape(.capsule)
    }

    private func paywallNotice(needed: Int) -> some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                Text("Free plan caps at \(RoutineService.freeTemplateCap) templates. Upgrade to save \(needed).")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color.yellow.opacity(0.08))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func atFreeCapForCount(_ needed: Int) -> Bool {
        guard !isPro else { return false }
        let existing = RoutineService.shared.routines.count
        return existing + needed > RoutineService.freeTemplateCap
    }

    private func opIcon(_ op: String) -> String {
        switch op {
        case "swap": return "↔"
        case "add": return "+"
        case "remove": return "−"
        case "change_sets": return "#"
        case "change_reps": return "↻"
        default: return "•"
        }
    }

    private func opTint(_ op: String) -> Color {
        switch op {
        case "add": return .green
        case "remove": return .red
        case "swap": return .blue
        default: return .orange
        }
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

    // MARK: - Actions

    private func generate() async {
        guard canGenerate else { return }
        isLoading = true
        errorMessage = nil
        response = nil
        do {
            let result = try await service.generate(
                routine: routine,
                userPrompt: prompt,
                profile: appState.profile
            )
            await MainActor.run {
                response = result
                isLoading = false
            }
        } catch let error as PlanModificationService.ModError {
            await MainActor.run {
                switch error {
                case .emptyResponse:
                    errorMessage = "Coach didn't return anything. Try rephrasing. Name the split, days per week, and any equipment constraints."
                case .decode:
                    errorMessage = "Coach's response wasn't readable. Please try again."
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if raw.contains("Daily limit") {
                    errorMessage = "Daily AI limit reached. Try again tomorrow."
                } else if raw.contains("network") || raw.localizedCaseInsensitiveContains("offline") {
                    errorMessage = "No connection. Check your internet and try again."
                } else {
                    errorMessage = "Coach error: \(raw). Try again."
                }
                isLoading = false
            }
        }
    }

    private func applyEdits(_ edits: [PlanModificationService.EditOp]) {
        guard let routine else { return }
        let updated = service.apply(edits, to: routine)
        _ = RoutineService.shared.save(updated, isPremium: isPro)
        onApplied(updated)
        dismiss()
    }

    private func saveAllTemplates(_ specs: [PlanModificationService.TemplateSpec]) {
        guard !atFreeCapForCount(specs.count) else { return }
        for spec in specs {
            let routine = spec.toRoutine()
            if RoutineService.shared.save(routine, isPremium: isPro) {
                savedTemplateCount += 1
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
