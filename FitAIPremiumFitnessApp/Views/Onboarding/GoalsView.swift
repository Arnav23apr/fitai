import SwiftUI

struct GoalsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var selected: Set<String> = []
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private let rows: [(String, String)] = [
        ("Build muscle", "Lose fat"),
        ("Get stronger", "Improve endurance"),
        ("Better posture", "Increase flexibility"),
        ("Run a marathon", "Feel more confident"),
        ("Build a routine", "Compete in fitness")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("in90Days", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("iWantTo", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("chooseTopGoals", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 10) {
                            chipButton(pair.0)
                            chipButton(pair.1)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                appState.profile.goals = Array(selected)
                onContinue()
            }) {
                Text(L.t("continue", lang))
                    .font(.headline)
                    .foregroundStyle(isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selected.isEmpty ? (isDark ? Color.white.opacity(0.3) : Color.black.opacity(0.3)) : (isDark ? Color.white : Color.black))
                    .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(selected.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }

    private func chipButton(_ title: String) -> some View {
        Button {
            if selected.contains(title) { selected.remove(title) } else { selected.insert(title) }
        } label: {
            Text(title)
                .font(.footnote.weight(.medium))
                .minimumScaleFactor(0.75)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(selected.contains(title) ? (isDark ? .black : .white) : .primary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .padding(.horizontal, 8)
                .background(selected.contains(title) ? (isDark ? Color.white : Color.black) : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                .clipShape(.rect(cornerRadius: 24))
        }
        .sensoryFeedback(.selection, trigger: selected.contains(title))
    }
}
