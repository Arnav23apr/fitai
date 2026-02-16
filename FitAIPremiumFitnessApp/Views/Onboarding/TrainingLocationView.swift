import SwiftUI

struct TrainingLocationView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private let options: [(icon: String, label: String, desc: String)] = [
        ("building.2", "Gym", "Full equipment access"),
        ("house", "Home", "Bodyweight & minimal gear"),
        ("figure.mixed.cardio", "Both", "Mix of gym and home")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Where do")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("you train?")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 14) {
                ForEach(options, id: \.label) { option in
                    Button {
                        selected = option.label
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(selected == option.label ? .black : .white.opacity(0.6))
                            Text(option.label)
                                .font(.headline)
                                .foregroundStyle(selected == option.label ? .black : .white)
                            Text(option.desc)
                                .font(.caption)
                                .foregroundStyle(selected == option.label ? .black.opacity(0.6) : .white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(selected == option.label ? Color.white : Color.white.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 20))
                    }
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                appState.profile.trainingLocation = selected
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
