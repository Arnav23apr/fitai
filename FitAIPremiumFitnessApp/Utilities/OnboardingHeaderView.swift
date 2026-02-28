import SwiftUI

struct OnboardingHeaderView: View {
    let progressIndex: Int
    let totalSteps: Int
    let showCloseButton: Bool
    let onBack: () -> Void
    let onClose: (() -> Void)?

    @State private var backTrigger: Int = 0
    @State private var closeTrigger: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(progressIndex + 1) / CGFloat(totalSteps)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                backTrigger += 1
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(OnboardingGlassButtonStyle())
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: backTrigger)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark
                              ? Color.white.opacity(0.15)
                              : Color.black.opacity(0.1))
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 4)
            .animation(.spring(duration: 0.45, bounce: 0.15), value: progress)

            if showCloseButton {
                Button {
                    closeTrigger += 1
                    onClose?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(OnboardingGlassButtonStyle())
                .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.6), trigger: closeTrigger)
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

struct OnboardingGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.5), value: configuration.isPressed)
    }
}
