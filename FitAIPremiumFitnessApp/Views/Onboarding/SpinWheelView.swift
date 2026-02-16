import SwiftUI

struct SpinWheelView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var appeared: Bool = false
    @State private var rotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var hasSpun: Bool = false
    @State private var resultDiscount: Int = 0

    private let segments: [Int] = [10, 20, 80, 15, 50, 25, 40, 20]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                if hasSpun {
                    Text("You won \(resultDiscount)%!")
                        .font(.system(.title, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Spin to Win")
                        .font(.system(.title, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Get an exclusive discount")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.top, 48)
            .opacity(appeared ? 1 : 0)
            .animation(.snappy, value: hasSpun)

            Spacer()

            ZStack {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.4), radius: 4)
                    .offset(y: -158)
                    .zIndex(1)

                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2
                    let segmentCount = segments.count
                    let segmentAngle = (2 * .pi) / Double(segmentCount)

                    for i in 0..<segmentCount {
                        let startAngle = Double(i) * segmentAngle - .pi / 2
                        let endAngle = startAngle + segmentAngle

                        var path = Path()
                        path.move(to: center)
                        path.addArc(center: center, radius: radius, startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
                        path.closeSubpath()

                        let isEven = i % 2 == 0
                        context.fill(path, with: .color(isEven ? Color.white.opacity(0.08) : Color.white.opacity(0.16)))

                        let midAngle = startAngle + segmentAngle / 2
                        let textRadius = radius * 0.68
                        let textPoint = CGPoint(
                            x: center.x + textRadius * cos(midAngle),
                            y: center.y + textRadius * sin(midAngle)
                        )

                        context.drawLayer { ctx in
                            ctx.translateBy(x: textPoint.x, y: textPoint.y)
                            ctx.rotate(by: .radians(midAngle + .pi / 2))
                            let text = Text("\(segments[i])%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            ctx.draw(text, at: .zero)
                        }
                    }
                }
                .frame(width: 290, height: 290)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 3
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.05), lineWidth: 8)
                        .padding(-4)
                )
                .rotationEffect(.degrees(rotation))
                .shadow(color: .white.opacity(0.05), radius: 20)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.15), Color.black],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 8)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            if hasSpun {
                Button(action: {
                    appState.profile.spinDiscount = resultDiscount
                    appState.profile.isPremium = true
                    onContinue()
                }) {
                    Text("Claim \(resultDiscount)% Off")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button(action: spinWheel) {
                    Text("Spin the Wheel")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isSpinning ? Color.white.opacity(0.3) : Color.white)
                        .clipShape(.rect(cornerRadius: 16))
                }
                .disabled(isSpinning)
                .padding(.horizontal, 24)
            }

            Button(action: onContinue) {
                Text("No thanks")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private func spinWheel() {
        guard !isSpinning else { return }
        isSpinning = true

        let selectedIndex = 2
        resultDiscount = segments[selectedIndex]

        let segmentAngle = 360.0 / Double(segments.count)
        let targetAngle = 360.0 - (Double(selectedIndex) * segmentAngle + segmentAngle / 2.0)
        let totalRotation = 360.0 * 5 + targetAngle

        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 4.5)) {
            rotation += totalRotation
        }

        Task {
            try? await Task.sleep(for: .seconds(4.7))
            withAnimation(.snappy) {
                hasSpun = true
                isSpinning = false
            }
        }
    }
}
