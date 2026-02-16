import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image("FitAILogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(.rect(cornerRadius: 24))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                VStack(spacing: 12) {
                    Text("Transform Your")
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Physique with AI")
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Text("Your personal AI fitness coach.\nScan, plan, and compete.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
            }

            Spacer()
            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
    }
}
