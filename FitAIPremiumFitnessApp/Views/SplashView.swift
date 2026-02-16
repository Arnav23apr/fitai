import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.92
    @State private var textOpacity: Double = 0
    @State private var textOffset: Double = 8

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            HStack(spacing: 14) {
                Image(colorScheme == .dark ? "FitAILogoWhite" : "FitAILogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
            }
            .opacity(logoOpacity)
            .scaleEffect(logoScale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                logoOpacity = 1
                logoScale = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                textOpacity = 1
                textOffset = 0
            }
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                withAnimation(.easeInOut(duration: 0.4)) {
                    logoOpacity = 0
                    logoScale = 1.04
                    textOpacity = 0
                }
                try? await Task.sleep(for: .seconds(0.45))
                onFinished()
            }
        }
    }
}
