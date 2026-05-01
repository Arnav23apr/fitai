import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.92
    @State private var dismissed: Bool = false

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            HStack(spacing: 14) {
                Image(colorScheme == .dark ? "FitAILogoWhite" : "FitAILogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
            }
            .opacity(logoOpacity)
            .scaleEffect(logoScale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                logoOpacity = 1
                logoScale = 1
            }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.0))
                guard !dismissed else { return }
                dismissed = true
                onFinished()
            }
        }
    }
}
