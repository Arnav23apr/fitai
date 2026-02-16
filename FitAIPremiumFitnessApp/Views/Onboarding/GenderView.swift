import SwiftUI

struct GenderView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false

    private let options: [(icon: String, label: String)] = [
        ("figure.stand", "Male"),
        ("figure.stand.dress", "Female"),
        ("figure.2", "Other")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("What's your")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("gender?")
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
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(selected == option.label ? .black : .white.opacity(0.6))
                                .frame(width: 32)
                            Text(option.label)
                                .font(.headline)
                                .foregroundStyle(selected == option.label ? .black : .white)
                            Spacer()
                            if selected == option.label {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 60)
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
                appState.profile.gender = selected
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
