import SwiftUI

struct PrimaryGoalView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private let options: [(icon: String, label: String, desc: String)] = [
        ("figure.strengthtraining.traditional", "Build Muscle", "Gain size and strength"),
        ("flame.fill", "Lose Fat", "Lean down and cut body fat"),
        ("arrow.triangle.2.circlepath", "Recomp", "Build muscle while losing fat")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Primary")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("Goal")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("What's your #1 focus right now?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 14) {
                ForEach(options, id: \.label) { option in
                    Button {
                        selected = option.label
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(selected == option.label ? .black : .white.opacity(0.5))
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.label)
                                    .font(.headline)
                                    .foregroundStyle(selected == option.label ? .black : .white)
                                Text(option.desc)
                                    .font(.caption)
                                    .foregroundStyle(selected == option.label ? .black.opacity(0.6) : .white.opacity(0.4))
                            }
                            Spacer()
                            if selected == option.label {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 72)
                        .background(selected == option.label ? Color.white : Color.white.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()

            Button(action: {
                appState.profile.primaryGoal = selected
                onContinue()
            }) {
                Text("Continue")
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
}
