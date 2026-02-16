import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var appeared: Bool = false

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

            Text("Sign In")
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
                    appState.profile.name = "Athlete"
                    onContinue()
                }) {
                    HStack(spacing: 10) {
                        GoogleLogo()
                            .frame(width: 20, height: 20)
                        Text("Sign in with Google")
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

                Button(action: {
                    appState.profile.name = "Athlete"
                    onContinue()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .font(.system(size: 18, weight: .medium))
                        Text("Continue with email")
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
                Text("By continuing you agree to Fit AI's")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Button("Terms and Conditions") {}
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .underline()
                    Text("and")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Privacy Policy") {}
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
            let r = min(w, h) / 2 * 0.9

            var bluePath = Path()
            bluePath.move(to: CGPoint(x: cx, y: cy))
            bluePath.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            bluePath.closeSubpath()
            context.fill(bluePath, with: .color(Color(red: 0.259, green: 0.522, blue: 0.957)))

            var greenPath = Path()
            greenPath.move(to: CGPoint(x: cx, y: cy))
            greenPath.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(45), endAngle: .degrees(150), clockwise: false)
            greenPath.closeSubpath()
            context.fill(greenPath, with: .color(Color(red: 0.204, green: 0.659, blue: 0.325)))

            var yellowPath = Path()
            yellowPath.move(to: CGPoint(x: cx, y: cy))
            yellowPath.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(150), endAngle: .degrees(230), clockwise: false)
            yellowPath.closeSubpath()
            context.fill(yellowPath, with: .color(Color(red: 0.984, green: 0.737, blue: 0.016)))

            var redPath = Path()
            redPath.move(to: CGPoint(x: cx, y: cy))
            redPath.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(230), endAngle: .degrees(315), clockwise: false)
            redPath.closeSubpath()
            context.fill(redPath, with: .color(Color(red: 0.918, green: 0.263, blue: 0.208)))

            let innerR = r * 0.55
            var innerCircle = Path()
            innerCircle.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
            context.fill(innerCircle, with: .color(.white))

            let barH = r * 0.36
            var bar = Path()
            bar.addRect(CGRect(x: cx, y: cy - barH / 2, width: r, height: barH))
            context.fill(bar, with: .color(Color(red: 0.259, green: 0.522, blue: 0.957)))
        }
    }
}
