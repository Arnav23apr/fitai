import SwiftUI

/// In-app feedback / bug-report sheet. User picks a category, writes a message,
/// and we POST to `submit_feedback` (rate-limited at 20/day per user).
/// Auto-attaches app version, iOS version, and device model so the admin
/// inbox doesn't need to ask "what version are you on?".
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// Optional preselected category. Profile passes `.bug` from "Report a Problem".
    var initialKind: FeedbackService.Kind = .bug

    @State private var kind: FeedbackService.Kind = .bug
    @State private var message: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submitState: SubmitState = .idle

    private var lang: String { appState.profile.selectedLanguage }

    private enum SubmitState: Equatable {
        case idle
        case sent
        case error(String)
    }

    private struct CategoryOption {
        let kind: FeedbackService.Kind
        let label: String
        let icon: String
        let tint: Color
    }

    private var categories: [CategoryOption] {
        [
            CategoryOption(kind: .bug,
                           label: L.t("feedbackKindBug", lang),
                           icon: "ant.fill",
                           tint: Color(red: 0.95, green: 0.30, blue: 0.30)),
            CategoryOption(kind: .suggestion,
                           label: L.t("feedbackKindSuggestion", lang),
                           icon: "lightbulb.fill",
                           tint: Color(red: 1.00, green: 0.75, blue: 0.10)),
            CategoryOption(kind: .question,
                           label: L.t("feedbackKindQuestion", lang),
                           icon: "questionmark.circle.fill",
                           tint: Color(red: 0.20, green: 0.55, blue: 1.00)),
            CategoryOption(kind: .other,
                           label: L.t("feedbackKindOther", lang),
                           icon: "ellipsis.bubble.fill",
                           tint: Color(red: 0.55, green: 0.40, blue: 1.00)),
        ]
    }

    private var canSubmit: Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 5 && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerLine
                    categoryGrid
                    messageField
                    if case .error(let err) = submitState {
                        errorBanner(err)
                    }
                    emailDirectRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("feedbackTitle", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("send", lang)) {
                        Task { await submit() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit)
                }
            }
            .overlay {
                if submitState == .sent {
                    successOverlay
                }
            }
        }
        .onAppear {
            kind = initialKind
        }
    }

    // MARK: - Header

    private var headerLine: some View {
        Text(L.t("feedbackHeadline", lang))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category grid

    private var categoryGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(categories.enumerated()), id: \.offset) { _, option in
                categoryButton(option)
            }
        }
    }

    private func categoryButton(_ option: CategoryOption) -> some View {
        let isSelected = kind == option.kind
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                kind = option.kind
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(option.tint.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: option.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(option.tint)
                }
                Text(option.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? option.tint : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? option.tint.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: kind)
    }

    // MARK: - Message field

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t("feedbackMessageLabel", lang))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.3)
                .textCase(.uppercase)

            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(placeholder(for: kind))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $message)
                    .font(.subheadline)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 160)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            HStack {
                Text("\(message.trimmingCharacters(in: .whitespacesAndNewlines).count) / 4000")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(L.t("feedbackVersionAttached", lang))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func placeholder(for kind: FeedbackService.Kind) -> String {
        switch kind {
        case .bug:        return L.t("feedbackPlaceholderBug", lang)
        case .suggestion: return L.t("feedbackPlaceholderSuggestion", lang)
        case .question:   return L.t("feedbackPlaceholderQuestion", lang)
        case .other:      return L.t("feedbackPlaceholderOther", lang)
        }
    }

    // MARK: - Email direct fallback

    private var emailDirectRow: some View {
        Button {
            if let url = URL(string: "mailto:team@fitai.health?subject=FitAI%20feedback") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.t("feedbackEmailDirectTitle", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(L.t("feedbackEmailDirectSubtitle", lang))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error / success states

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.10))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var successOverlay: some View {
        ZStack {
            Color(.systemBackground).opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text(L.t("feedbackThanks", lang))
                    .font(.title3.weight(.bold))
                Text(L.t("feedbackThanksDetail", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .transition(.scale.combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                dismiss()
            }
        }
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let result = await FeedbackService.shared.submitFeedback(kind: kind, message: trimmed)
        switch result {
        case .success:
            withAnimation(.snappy(duration: 0.3)) { submitState = .sent }
        case .rateLimited:
            submitState = .error(L.t("feedbackRateLimited", lang))
        case .validation(let msg):
            submitState = .error(msg)
        case .failure:
            submitState = .error(L.t("feedbackSendFailed", lang))
        }
    }
}
