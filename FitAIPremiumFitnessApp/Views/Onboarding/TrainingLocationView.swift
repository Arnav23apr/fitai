import SwiftUI

struct PullUpBarIcon: View {
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let barY = h * 0.18
            let barThickness = w * 0.09
            let poleWidth = w * 0.09
            let poleInset = w * 0.22

            var bar = Path()
            bar.addRoundedRect(
                in: CGRect(x: w * 0.08, y: barY, width: w * 0.84, height: barThickness),
                cornerSize: CGSize(width: barThickness / 2, height: barThickness / 2)
            )
            context.fill(bar, with: .foreground)

            var leftPole = Path()
            leftPole.addRoundedRect(
                in: CGRect(x: poleInset, y: barY, width: poleWidth, height: h * 0.82 - barY),
                cornerSize: CGSize(width: poleWidth / 2, height: poleWidth / 2)
            )
            context.fill(leftPole, with: .foreground)

            var rightPole = Path()
            rightPole.addRoundedRect(
                in: CGRect(x: w - poleInset - poleWidth, y: barY, width: poleWidth, height: h * 0.82 - barY),
                cornerSize: CGSize(width: poleWidth / 2, height: poleWidth / 2)
            )
            context.fill(rightPole, with: .foreground)

            let headR = w * 0.08
            let headCX = w / 2
            let headCY = barY + barThickness + headR + h * 0.02
            var head = Path()
            head.addEllipse(in: CGRect(x: headCX - headR, y: headCY - headR, width: headR * 2, height: headR * 2))
            context.fill(head, with: .foreground)

            let bodyTop = headCY + headR + h * 0.01
            var body = Path()
            body.addRoundedRect(
                in: CGRect(x: headCX - poleWidth * 0.45, y: bodyTop, width: poleWidth * 0.9, height: h * 0.28),
                cornerSize: CGSize(width: 2, height: 2)
            )
            context.fill(body, with: .foreground)

            let armY = bodyTop + h * 0.01
            let armThickness = poleWidth * 0.55
            var leftArm = Path()
            leftArm.move(to: CGPoint(x: headCX - poleWidth * 0.3, y: armY))
            leftArm.addLine(to: CGPoint(x: poleInset + poleWidth / 2, y: barY + barThickness))
            context.stroke(leftArm, with: .foreground, lineWidth: armThickness)

            var rightArm = Path()
            rightArm.move(to: CGPoint(x: headCX + poleWidth * 0.3, y: armY))
            rightArm.addLine(to: CGPoint(x: w - poleInset - poleWidth / 2, y: barY + barThickness))
            context.stroke(rightArm, with: .foreground, lineWidth: armThickness)

            let legTop = bodyTop + h * 0.28
            let legLen = h * 0.18
            var leftLeg = Path()
            leftLeg.move(to: CGPoint(x: headCX - poleWidth * 0.2, y: legTop))
            leftLeg.addLine(to: CGPoint(x: headCX - w * 0.08, y: legTop + legLen))
            context.stroke(leftLeg, with: .foreground, lineWidth: armThickness)

            var rightLeg = Path()
            rightLeg.move(to: CGPoint(x: headCX + poleWidth * 0.2, y: legTop))
            rightLeg.addLine(to: CGPoint(x: headCX + w * 0.08, y: legTop + legLen))
            context.stroke(rightLeg, with: .foreground, lineWidth: armThickness)
        }
        .frame(width: size, height: size)
    }
}

struct TrainingLocationView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false
    @State private var selectedEquipment: Set<String> = []

    private var options: [(icon: String, labelKey: String, descKey: String)] {
        [
            ("building.2", "Gym", "Full equipment access"),
            ("house", "Home", "Bodyweight & minimal gear"),
            ("figure.mixed.cardio", "Both", "Mix of gym and home")
        ]
    }

    private let equipmentKeys: [(icon: String, labelKey: String, isPullUpBar: Bool)] = [
        ("dumbbell.fill", "Dumbbells", false),
        ("", "Pull-up Bar", true),
        ("figure.walk", "Bodyweight Only", false)
    ]

    private var showEquipment: Bool {
        selected == "Home" || selected == "Both"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(appState.t("Where do"))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(appState.t("you train?"))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 14) {
                ForEach(options, id: \.labelKey) { option in
                    let label = appState.t(option.labelKey)
                    let isSelected = selected == option.labelKey
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            selected = option.labelKey
                            if option.labelKey == "Gym" {
                                selectedEquipment = []
                            }
                        }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                            Text(label)
                                .font(.headline)
                                .foregroundStyle(isSelected ? .black : .white)
                            Text(appState.t(option.descKey))
                                .font(.caption)
                                .foregroundStyle(isSelected ? .black.opacity(0.6) : .white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(isSelected ? Color.white : Color.white.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 20))
                    }
                    .sensoryFeedback(.selection, trigger: selected)
                }

                if showEquipment {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(appState.t("Available equipment"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.leading, 4)

                        HStack(spacing: 10) {
                            ForEach(equipmentKeys, id: \.labelKey) { eq in
                                let translatedLabel = appState.t(eq.labelKey)
                                let isSelected = selectedEquipment.contains(eq.labelKey)
                                Button {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        if isSelected {
                                            selectedEquipment.remove(eq.labelKey)
                                        } else {
                                            selectedEquipment.insert(eq.labelKey)
                                        }
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        if eq.isPullUpBar {
                                            PullUpBarIcon(size: 24)
                                                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                                        } else {
                                            Image(systemName: eq.icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                                        }
                                        Text(translatedLabel)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 80)
                                    .background(isSelected ? Color.white : Color.white.opacity(0.06))
                                    .clipShape(.rect(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .sensoryFeedback(.selection, trigger: selectedEquipment)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                appState.profile.trainingLocation = selected
                onContinue()
            }) {
                Text(appState.t("Continue"))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selected.isEmpty ? Color.white.opacity(0.3) : Color.white)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(selected.isEmpty)
            .padding(.horizontal, 24)
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
