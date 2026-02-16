import SwiftUI

struct HoldingBackView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: Set<String> = []
    @State private var appeared: Bool = false

    private let rows: [(String, String)] = [
        ("Lack of motivation", "No workout plan"),
        ("Poor nutrition", "Inconsistency"),
        ("Time management", "Injuries or pain"),
        ("Low energy", "Not seeing results"),
        ("Gym intimidation", "Don't know where to start")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(appState.t("What's holding"))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(appState.t("you back?"))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(appState.t("Select all that apply"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 12) {
                            chipButton(pair.0)
                            chipButton(pair.1)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                appState.profile.holdingBack = Array(selected)
                onContinue()
            }) {
                Text(appState.t("Continue"))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selected.isEmpty ? Color.white.opacity(0.3) : Color.white)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(selected.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private func chipButton(_ key: String) -> some View {
        let isSelected = selected.contains(key)
        return Button {
            if isSelected {
                selected.remove(key)
            } else {
                selected.insert(key)
            }
        } label: {
            Text(appState.t(key))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isSelected ? Color.white : Color.white.opacity(0.08))
                .clipShape(.rect(cornerRadius: 24))
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
