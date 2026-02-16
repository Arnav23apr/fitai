import SwiftUI

struct TrainingExperienceView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private let options: [(icon: String, title: String, subtitle: String)] = [
        ("leaf", "Beginner", "Less than 6 months"),
        ("flame", "Intermediate", "6 months – 2 years"),
        ("bolt.fill", "Advanced", "2+ years of training"),
        ("trophy.fill", "Expert", "Competitive level")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Training")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("Experience")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("How long have you been training?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 12) {
                ForEach(options, id: \.title) { option in
                    Button {
                        selected = option.title
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selected == option.title ? .black : .white.opacity(0.5))
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.headline)
                                    .foregroundStyle(selected == option.title ? .black : .white)
                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(selected == option.title ? .black.opacity(0.6) : .white.opacity(0.4))
                            }
                            Spacer()
                            if selected == option.title {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 64)
                        .background(selected == option.title ? Color.white : Color.white.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 16))
                    }
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                appState.profile.trainingExperience = selected
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
