import SwiftUI

/// Captures the user's first name early in onboarding so subsequent
/// screens can address them by name. Personalization-bias research
/// (Cialdini, Brendl) shows your own name spikes attention and lifts
/// downstream commitment. Single low-friction text input — no
/// validation beyond non-empty trim.
struct NameView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var nameFocused: Bool
    var onContinue: () -> Void

    @State private var name: String = ""
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canContinue: Bool { !trimmed.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("nameTitle", lang))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("nameTitle2", lang))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("nameSubtitle", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Spacer()

            TextField(L.t("namePlaceholder", lang), text: $name)
                .font(.system(size: 22, weight: .medium))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit { if canContinue { commit() } }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(Color.primary.opacity(0.05))
                .clipShape(.rect(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            canContinue ? Color.primary.opacity(0.18) : Color.clear,
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .animation(.snappy(duration: 0.2), value: canContinue)

            Spacer()
            Spacer()

            Button(action: commit) {
                Text(L.t("nameContinue", lang))
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canContinue ? Color.primary : Color.primary.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 28))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
            .sensoryFeedback(.impact(weight: .light), trigger: appeared)
        }
        .onAppear {
            name = appState.profile.name
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                nameFocused = true
            }
        }
    }

    private func commit() {
        appState.profile.name = trimmed
        appState.saveProfile()
        nameFocused = false
        onContinue()
    }
}
