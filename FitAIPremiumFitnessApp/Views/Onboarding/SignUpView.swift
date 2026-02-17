import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onContinue) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Text(L.t("logIn", lang))
                .font(.system(.title2, design: .default, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 14) {
                SignInWithAppleButton(.signIn) { request in
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
                    appState.profile.name = "Athlete"
                    onContinue()
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
