import SwiftUI

struct ReferralCodeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var code: String = ""
    @State private var appeared: Bool = false
    @State private var isFocused: Bool = false

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Referral Code")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Got a code from a friend? Enter it below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        .frame(width: 80, height: 80)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(isDark ? .white.opacity(0.5) : .black.opacity(0.4))
                }

                VStack(spacing: 8) {
                    TextField("", text: $code, prompt: Text("Enter code").foregroundStyle(.tertiary))
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 24)
                        .frame(height: 56)
                        .background(isDark ? Color.white.opacity(0.06) : Color(.systemGray6))
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(!code.isEmpty ? (isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.15)) : Color.clear, lineWidth: 1)
                        )

                    if !code.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("Code entered")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.snappy(duration: 0.25), value: code.isEmpty)
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()

            VStack(spacing: 14) {
                Button(action: {
                    appState.profile.referralCode = code
                    onContinue()
                }) {
                    Text(code.isEmpty ? "Continue" : "Apply & Continue")
                        .font(.headline)
                        .foregroundStyle(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isDark ? .white : .black)
                        .clipShape(.rect(cornerRadius: 28))
                }

                if code.isEmpty {
                    Button(action: onContinue) {
                        Text("I don't have a code")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
