import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var agreedToTerms: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("Create Your Account")
                        .font(.system(.title, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Sign up to save your progress")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                                    .compactMap { $0 }
                                    .joined(separator: " ")
                                if !name.isEmpty { appState.profile.name = name }
                                if let email = credential.email { appState.profile.email = email }
                            }
                            onContinue()
                        case .failure:
                            break
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .clipShape(.rect(cornerRadius: 16))

                    Button(action: {
                        appState.profile.name = "Athlete"
                        onContinue()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18))
                            Text("Continue with Email")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 24)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
            Spacer()

            VStack(spacing: 16) {
                Button(action: { agreedToTerms.toggle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundStyle(agreedToTerms ? .white : .white.opacity(0.4))
                        Text("I agree to the Terms & Privacy Policy")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Button(action: onContinue) {
                    Text("Existing user? Log in")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .underline()
                }
            }
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
