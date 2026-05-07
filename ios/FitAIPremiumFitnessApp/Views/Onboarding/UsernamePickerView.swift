import SwiftUI

/// Reusable username picker — used by the onboarding step (new users) and
/// the backfill modal (existing username-less accounts). Renders a single
/// text field, debounced availability check, fitness-themed suggestion
/// chips, and a Continue button that's disabled until the chosen handle is
/// valid + available.
///
/// Caller decides what "Continue" means via `onConfirm` — usually persists
/// the username and dismisses / advances onboarding.
struct UsernamePickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let isModal: Bool
    let onConfirm: (String) async -> Void

    @State private var input: String = ""
    @State private var checkState: CheckState = .idle
    @State private var suggestions: [String] = []
    @State private var checkTask: Task<Void, Never>? = nil
    @State private var isSubmitting: Bool = false
    @State private var ctaTapCount: Int = 0

    private enum CheckState: Equatable {
        case idle
        case checking
        case available
        case taken
        case invalid(String)
        case error
    }

    private var seed: String {
        // Prefer first name; fall back to email local part.
        let name = appState.profile.name
            .split(separator: " ").first.map(String.init) ?? ""
        if !name.isEmpty { return name }
        return appState.profile.email
    }

    private var canConfirm: Bool {
        checkState == .available && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    inputField
                    statusLine
                    suggestionChips
                }
                .padding(.horizontal, 24)
                .padding(.top, 72) // clear the OnboardingHeaderView (back arrow + progress bar)
            }

            ctaButton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear { generateSuggestions() }
        .onChange(of: input) { _, newValue in scheduleCheck(for: newValue) }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.largeTitle, weight: .bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            Text("@")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.secondary)
            TextField("yourhandle", text: Binding(
                get: { input },
                set: { input = $0.lowercased() }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .submitLabel(.done)

            statusIcon
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color.primary.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch checkState {
        case .checking:
            ProgressView().controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
    }

    private var statusLine: some View {
        Group {
            switch checkState {
            case .available:
                Label("@\(input) is yours.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .taken:
                Label("@\(input) is taken.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .invalid(let msg):
                Label(msg, systemImage: "info.circle.fill")
                    .foregroundStyle(.red)
            case .error:
                Label("Couldn't check — try again.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
            case .checking:
                Label("Checking…", systemImage: "ellipsis")
                    .foregroundStyle(.secondary)
            case .idle:
                Text("3-20 chars · letters, numbers, _ and . only")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUGGESTIONS")
                .font(.caption2.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        input = s
                    } label: {
                        Text("@\(s)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.orange.opacity(0.10))
                            .foregroundStyle(.primary)
                            .overlay(
                                Capsule().strokeBorder(Color.orange.opacity(0.30), lineWidth: 1)
                            )
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var ctaButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().tint(Color(.systemBackground))
                }
                Text("Save handle")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(canConfirm ? Color(.systemBackground) : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canConfirm ? Color.primary : Color.primary.opacity(0.18))
            .clipShape(.rect(cornerRadius: 28))
        }
        .disabled(!canConfirm)
        .sensoryFeedback(.impact(weight: .heavy), trigger: ctaTapCount)
    }

    // MARK: - Logic

    private func generateSuggestions() {
        suggestions = UsernameSuggester.suggestions(seed: seed)
        // If field is empty, drop the first suggestion in so the user has
        // something to evaluate immediately. They can edit or pick another.
        if input.isEmpty, let first = suggestions.first {
            input = first
        }
    }

    /// Debounced 350ms — runs format validation locally first, only hits
    /// the network if the candidate passes the local checks.
    private func scheduleCheck(for candidate: String) {
        checkTask?.cancel()
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.isEmpty { checkState = .idle; return }
        if let err = UsernameSuggester.validationError(trimmed) {
            checkState = .invalid(err); return
        }
        checkState = .checking

        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            let userId = appState.currentUserIdPublic
            let available = await SupabaseSyncService.shared
                .isUsernameAvailable(trimmed, excludingUserId: userId)
            if Task.isCancelled { return }
            await MainActor.run {
                guard input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                switch available {
                case .some(true):  checkState = .available
                case .some(false): checkState = .taken
                case .none:        checkState = .error
                }
            }
        }
    }

    private func submit() async {
        guard canConfirm else { return }
        ctaTapCount += 1
        isSubmitting = true
        defer { isSubmitting = false }
        let final = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        await onConfirm(final)
    }
}

// FlowLayout used for suggestion chips is defined module-wide in
// Utilities/ChipGridView.swift — local copy removed to avoid the
// "invalid redeclaration" compile error against the internal struct.
