import SwiftUI
import AuthenticationServices
import CryptoKit

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var appeared: Bool = false
    @State private var showEmailForm: Bool = false
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSignUp: Bool = false
    @State private var showConfirmationAlert: Bool = false
    @State private var currentNonce: String = ""

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        VStack(spacing: 0) {
            Text(L.t("logIn", lang))
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 60)

            Spacer()

            VStack(spacing: 14) {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = Self.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                              let tokenData = credential.identityToken,
                              let idToken = String(data: tokenData, encoding: .utf8) else { return }
                        let nonce = currentNonce
                        Task {
                            await appState.signInWithApple(
                                idToken: idToken,
                                nonce: nonce,
                                fullName: credential.fullName,
                                email: credential.email
                            )
                            if appState.authError == nil && !appState.isAuthenticating {
                                onContinue()
                            }
                        }
                    case .failure:
                        break
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 56)
                .clipShape(.rect(cornerRadius: 28))

                Button(action: {
                    Task {
                        await appState.signInWithGoogle()
                        if appState.authError == nil && !appState.isAuthenticating {
                            if !appState.profile.email.isEmpty {
                                onContinue()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 10) {
                        if appState.isAuthenticating {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            Image("GoogleLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text(L.t("signInGoogle", lang))
                                .font(.system(size: 19, weight: .medium))
                        }
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemBackground))
                    .clipShape(.rect(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .disabled(appState.isAuthenticating)

                Button(action: {
                    withAnimation(.spring(duration: 0.35)) {
                        showEmailForm = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .font(.system(size: 18, weight: .medium))
                        Text(L.t("continueEmail", lang))
                            .font(.system(size: 19, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.systemBackground))
                    .clipShape(.rect(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Color(.systemGray4), lineWidth: 1)
                    )
                }

                if showEmailForm {
                    emailFormSection
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            VStack(spacing: 0) {
                Text(L.t("byContinuingFitAI", lang))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Button(L.t("termsAndConditions", lang)) {}
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .underline()
                    Text(L.t("and", lang))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button(L.t("privacyPolicy", lang)) {}
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .underline()
                }
            }
            .padding(.bottom, 24)
            .opacity(appeared ? 1 : 0)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
        .alert("Check Your Email", isPresented: $showConfirmationAlert) {
            Button("OK") {}
        } message: {
            Text("We sent a confirmation link to \(email). Please verify your email to sign in.")
        }
        .onChange(of: appState.emailConfirmationNeeded) { _, newValue in
            if newValue {
                showConfirmationAlert = true
                appState.emailConfirmationNeeded = false
            }
        }
    }

    private var emailFormSection: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 14))

            SecureField("Password", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 14))

            if let error = appState.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: submitEmail) {
                HStack(spacing: 8) {
                    if appState.isAuthenticating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    isFormValid
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.4)
                )
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(!isFormValid || appState.isAuthenticating)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    appState.authError = nil
                }
            }) {
                Text(isSignUp ? "Already have an account? **Sign In**" : "Don't have an account? **Sign Up**")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private var isFormValid: Bool {
        email.contains("@") && email.contains(".") && password.count >= 6
    }

    private func submitEmail() {
        Task {
            if isSignUp {
                await appState.signUpWithEmail(email: email, password: password)
            } else {
                await appState.signInWithEmail(email: email, password: password)
            }
            if appState.authError == nil && !appState.isAuthenticating && appState.isLoggedIn {
                onContinue()
            }
        }
    }
}

struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            let outerR = min(w, h) / 2 * 0.88
            let strokeW = outerR * 0.38
            let r = outerR - strokeW / 2

            let blue = Color(red: 0.259, green: 0.522, blue: 0.957)
            let green = Color(red: 0.204, green: 0.659, blue: 0.325)
            let yellow = Color(red: 0.984, green: 0.737, blue: 0.016)
            let red = Color(red: 0.918, green: 0.263, blue: 0.208)

            let center = CGPoint(x: cx, y: cy)
            let arcs: [(start: Double, end: Double, color: Color)] = [
                (-40, 40, blue),
                (40, 150, green),
                (150, 230, yellow),
                (230, 320, red),
            ]

            for arc in arcs {
                var path = Path()
                path.addArc(center: center, radius: r, startAngle: .degrees(arc.start), endAngle: .degrees(arc.end), clockwise: false)
                context.stroke(path, with: .color(arc.color), style: StrokeStyle(lineWidth: strokeW, lineCap: .butt))
            }

            let barH = strokeW
            var bar = Path()
            bar.addRect(CGRect(x: cx - 1, y: cy - barH / 2, width: outerR + 1, height: barH))
            context.fill(bar, with: .color(blue))
        }
    }
}
