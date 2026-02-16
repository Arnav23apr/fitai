import SwiftUI

struct ReferralCodeView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var code: String = ""
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(appState.t("Referral Code"))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(appState.t("Got a code from a friend?"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.3))

                TextField("", text: $code, prompt: Text(appState.t("Enter code")).foregroundStyle(.white.opacity(0.3)))
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 24)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
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
                    Text(code.isEmpty ? appState.t("Continue") : appState.t("Apply & Continue"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 16))
                }

                if code.isEmpty {
                    Button(action: onContinue) {
                        Text(appState.t("I don't have a code"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
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
