import SwiftUI

struct SplashView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.8

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("FitAILogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(.rect(cornerRadius: 28))
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoOpacity = 1
                logoScale = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                withAnimation(.easeInOut(duration: 0.4)) {
                    logoOpacity = 0
                    logoScale = 1.1
                }
                try? await Task.sleep(for: .seconds(0.5))
                onFinished()
            }
        }
    }
}
