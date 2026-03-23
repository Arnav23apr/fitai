import SwiftUI

struct PhotoTipsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    private let tips: [(icon: String, color: Color, title: String, description: String)] = [
        ("sun.max.fill", .yellow, "Good Lighting", "Stand near a window or in a well-lit room. Avoid harsh shadows or backlighting. Natural light gives the most accurate scan."),
        ("figure.stand", .blue, "Neutral Pose", "Stand straight with arms slightly away from your body. Feet shoulder-width apart. Look straight ahead, not at the camera."),
        ("tshirt.fill", .orange, "Minimal Clothing", "Wear fitted clothing or no shirt (for males). The AI needs to see your body shape clearly. Baggy clothes hide muscle definition."),
        ("photo", .green, "Plain Background", "Stand against a plain white or light-coloured wall. Remove clutter from behind you. High contrast between you and the background helps accuracy."),
        ("ruler", .purple, "Full Body Shot", "The camera should capture from your head to your feet. Hold the phone 6–8 feet away, or use a timer on a flat surface."),
        ("camera.rotate.fill", .cyan, "Front & Back", "Take both a front-facing and back-facing photo for the most accurate muscle analysis. Side photos are optional."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                        tipCard(tip)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Photo Guidelines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private func tipCard(_ tip: (icon: String, color: Color, title: String, description: String)) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tip.icon)
                .font(.system(size: 18))
                .foregroundStyle(tip.color)
                .frame(width: 44, height: 44)
                .background(tip.color.opacity(0.12))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(tip.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}
