import SwiftUI

struct ResultsGraphView: View {
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var appeared: Bool = false
    @State private var fitAIProgress: CGFloat = 0
    @State private var traditionalProgress: CGFloat = 0
    @State private var showLabels: Bool = false
    @State private var showSubtext: Bool = false
    @State private var hapticTick: Int = 0
    @State private var animationTimer: Timer?
    @State private var animationStart: Date?

    private var isDark: Bool { colorScheme == .dark }

    private let drawDuration: Double = 2.2
    private let drawDelay: Double = 0.5
    private let traditionalDelay: Double = 0.2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Fit AI creates")
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                Text("long-term results")
                    .font(.system(.largeTitle, design: .default, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            graphCard
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

            Spacer()

            Button(action: onContinue) {
                Text("Next")
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(.rect(cornerRadius: 28))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.4), trigger: hapticTick)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            startGraphAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    private var graphCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Weight")
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            ZStack {
                graphArea
            }
            .frame(height: 180)

            legendRow
                .opacity(showLabels ? 1 : 0)

            HStack {
                Text("Month 1")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Month 6")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .opacity(showLabels ? 1 : 0)

            Text("80% of Fit AI users maintain their\nweight loss even 6 months later")
                .font(.system(.footnote, design: .default, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .opacity(showSubtext ? 1 : 0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }

    private var graphArea: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let topPad: CGFloat = 10
            let bottomPad: CGFloat = 10

            let gridColor = Color.gray.opacity(0.12)
            for i in 0...4 {
                let y = topPad + (h - topPad - bottomPad) * CGFloat(i) / 4.0
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.addLine(to: CGPoint(x: w, y: y))
                context.stroke(gridPath, with: .color(gridColor), lineWidth: 0.5)
            }

            let fitAIPoints = fitAICurvePoints(in: size)
            let traditionalPoints = traditionalCurvePoints(in: size)

            let tradDrawCount = max(1, Int(CGFloat(traditionalPoints.count) * traditionalProgress))
            let tradVisible = Array(traditionalPoints.prefix(tradDrawCount))

            if tradVisible.count > 1 {
                var tradFill = Path()
                tradFill.move(to: CGPoint(x: tradVisible[0].x, y: h - bottomPad))
                for pt in tradVisible { tradFill.addLine(to: pt) }
                tradFill.addLine(to: CGPoint(x: tradVisible.last!.x, y: h - bottomPad))
                tradFill.closeSubpath()
                context.fill(tradFill, with: .linearGradient(
                    Gradient(colors: [Color.red.opacity(0.12), Color.red.opacity(0.02)]),
                    startPoint: CGPoint(x: w / 2, y: topPad),
                    endPoint: CGPoint(x: w / 2, y: h - bottomPad)
                ))

                var tradLine = Path()
                tradLine.move(to: tradVisible[0])
                for pt in tradVisible.dropFirst() { tradLine.addLine(to: pt) }
                context.stroke(tradLine, with: .color(Color.red.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            let fitDrawCount = max(1, Int(CGFloat(fitAIPoints.count) * fitAIProgress))
            let fitVisible = Array(fitAIPoints.prefix(fitDrawCount))

            if fitVisible.count > 1 {
                var fitLine = Path()
                fitLine.move(to: fitVisible[0])
                for pt in fitVisible.dropFirst() { fitLine.addLine(to: pt) }
                context.stroke(fitLine, with: .color(Color(.label)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            if fitAIProgress > 0.01, let first = fitVisible.first {
                let circleSize: CGFloat = 10
                context.fill(
                    Path(ellipseIn: CGRect(x: first.x - circleSize / 2, y: first.y - circleSize / 2, width: circleSize, height: circleSize)),
                    with: .color(Color(.systemBackground))
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: first.x - circleSize / 2, y: first.y - circleSize / 2, width: circleSize, height: circleSize)),
                    with: .color(Color(.label)), lineWidth: 2
                )
            }

            if fitAIProgress >= 0.98, let last = fitVisible.last {
                let circleSize: CGFloat = 10
                context.fill(
                    Path(ellipseIn: CGRect(x: last.x - circleSize / 2, y: last.y - circleSize / 2, width: circleSize, height: circleSize)),
                    with: .color(Color(.systemBackground))
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: last.x - circleSize / 2, y: last.y - circleSize / 2, width: circleSize, height: circleSize)),
                    with: .color(Color(.label)), lineWidth: 2
                )
            }

            if fitDrawCount > 1, let tip = fitVisible.last, fitAIProgress < 0.98 {
                let glowSize: CGFloat = 6
                context.fill(
                    Path(ellipseIn: CGRect(x: tip.x - glowSize / 2, y: tip.y - glowSize / 2, width: glowSize, height: glowSize)),
                    with: .color(Color(.label).opacity(0.6))
                )
            }

            if traditionalProgress > 0.6 {
                let labelIdx = min(Int(CGFloat(traditionalPoints.count) * 0.55), traditionalPoints.count - 1)
                let labelPt = traditionalPoints[labelIdx]
                let resolved = context.resolve(
                    Text("Traditional Diet")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.8))
                )
                context.draw(resolved, at: CGPoint(x: labelPt.x + 20, y: labelPt.y - 14))
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(isDark ? "FitAILogoWhite" : "FitAILogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .clipShape(.rect(cornerRadius: 4))
                Text("Fit AI")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text("Traditional")
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func fitAICurvePoints(in size: CGSize) -> [CGPoint] {
        let w = size.width
        let h = size.height
        let topPad: CGFloat = 10
        let bottomPad: CGFloat = 10
        let usableH = h - topPad - bottomPad
        let steps = 60

        return (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            let x = t * w
            let startY: CGFloat = 0.15
            let endY: CGFloat = 0.85
            let curve = startY + (endY - startY) * (1 - pow(1 - t, 2.2))
            let y = topPad + curve * usableH
            return CGPoint(x: x, y: y)
        }
    }

    private func traditionalCurvePoints(in size: CGSize) -> [CGPoint] {
        let w = size.width
        let h = size.height
        let topPad: CGFloat = 10
        let bottomPad: CGFloat = 10
        let usableH = h - topPad - bottomPad
        let steps = 60

        return (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            let x = t * w
            let dip = sin(t * .pi * 0.9) * 0.45
            let rebound = t > 0.45 ? pow((t - 0.45) / 0.55, 1.8) * 0.35 : 0
            let normalizedY = 0.15 + dip - rebound + (t > 0.45 ? 0 : 0)
            let finalY = min(max(normalizedY, 0.05), 0.95)
            let y = topPad + (1 - finalY) * usableH
            return CGPoint(x: x, y: y)
        }
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func startGraphAnimation() {
        let startTime = Date().addingTimeInterval(drawDelay)
        animationStart = startTime
        var lastHapticBucket = -1

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let now = Date()
            let elapsed = now.timeIntervalSince(startTime)

            guard elapsed > 0 else { return }

            let fitT = min(CGFloat(elapsed / drawDuration), 1.0)
            let tradElapsed = elapsed - traditionalDelay
            let tradT = tradElapsed > 0 ? min(CGFloat(tradElapsed / drawDuration), 1.0) : 0

            fitAIProgress = easeInOut(fitT)
            traditionalProgress = tradElapsed > 0 ? easeInOut(tradT) : 0

            let hapticBucket = Int(fitT * 12)
            if hapticBucket > lastHapticBucket {
                lastHapticBucket = hapticBucket
                hapticTick += 1
            }

            if fitT >= 1.0 && tradT >= 1.0 {
                timer.invalidate()
                animationTimer = nil

                withAnimation(.easeOut(duration: 0.4)) {
                    showLabels = true
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                    showSubtext = true
                }
            }
        }
    }
}
