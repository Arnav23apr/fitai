import SwiftUI

struct ResultsGraphView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    private var lang: String { appState.profile.selectedLanguage }

    @State private var appeared: Bool = false
    @State private var fitAIProgress: CGFloat = 0
    @State private var traditionalProgress: CGFloat = 0
    @State private var showLabels: Bool = false
    @State private var showSubtext: Bool = false
    @State private var hapticTick: Int = 0
    @State private var animationTimer: Timer?
    @State private var animationStart: Date?

    private var isDark: Bool { colorScheme == .dark }

    private let drawDuration: Double = 2.0
    private let drawDelay: Double = 0.5
    private let traditionalDelay: Double = 0.2
    private let dashPattern: [CGFloat] = [4, 6]

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L.t("fitAICreates", lang))
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                Text(L.t("longTermResults", lang))
                    .font(.system(.largeTitle, design: .default, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            graphCard
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

            Spacer()

            Button(action: onContinue) {
                Text(L.t("next", lang))
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
            Text(L.t("yourPhysique", lang))
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
                Text(L.t("month1", lang))
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L.t("month6", lang))
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .opacity(showLabels ? 1 : 0)

            Text(L.t("usersMainGains", lang))
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
                let y = graphTopPad + (h - graphTopPad - graphBottomPad) * CGFloat(i) / 4.0
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: graphLeftPad, y: y))
                gridPath.addLine(to: CGPoint(x: w - graphRightPad, y: y))
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
                    Gradient(colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.02)]),
                    startPoint: CGPoint(x: w / 2, y: topPad),
                    endPoint: CGPoint(x: w / 2, y: h - bottomPad)
                ))

                var tradLine = Path()
                tradLine.move(to: tradVisible[0])
                for pt in tradVisible.dropFirst() { tradLine.addLine(to: pt) }
                context.stroke(tradLine, with: .color(Color.blue.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: dashPattern))
            }

            let fitDrawCount = max(1, Int(CGFloat(fitAIPoints.count) * fitAIProgress))
            let fitVisible = Array(fitAIPoints.prefix(fitDrawCount))

            if fitVisible.count > 1 {
                var fitLine = Path()
                fitLine.move(to: fitVisible[0])
                for pt in fitVisible.dropFirst() { fitLine.addLine(to: pt) }
                context.stroke(fitLine, with: .color(Color(.label)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: dashPattern))
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


        }
    }

    private var legendRow: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                Text(L.t("fitAITraining", lang))
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 8, height: 8)
                Text(L.t("traditionalTraining", lang))
                    .font(.system(.caption, design: .default, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private let graphLeftPad: CGFloat = 16
    private let graphRightPad: CGFloat = 16
    private let graphTopPad: CGFloat = 16
    private let graphBottomPad: CGFloat = 16

    private func fitAICurvePoints(in size: CGSize) -> [CGPoint] {
        let w = size.width
        let h = size.height
        let usableW = w - graphLeftPad - graphRightPad
        let usableH = h - graphTopPad - graphBottomPad
        let steps = 60

        return (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            let x = graphLeftPad + t * usableW
            let startY: CGFloat = 0.82
            let endY: CGFloat = 0.12
            let curve = startY + (endY - startY) * pow(t, 1.6)
            let y = graphTopPad + curve * usableH
            return CGPoint(x: x, y: y)
        }
    }

    private func traditionalCurvePoints(in size: CGSize) -> [CGPoint] {
        let w = size.width
        let h = size.height
        let usableW = w - graphLeftPad - graphRightPad
        let usableH = h - graphTopPad - graphBottomPad
        let steps = 60

        return (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            let x = graphLeftPad + t * usableW
            let rise = sin(t * .pi * 0.7) * 0.3
            let plateau = t > 0.5 ? (t - 0.5) * 0.15 : 0
            let normalizedY = 0.82 - rise + plateau
            let finalY = min(max(normalizedY, 0.15), 0.90)
            let y = graphTopPad + finalY * usableH
            return CGPoint(x: x, y: y)
        }
    }

    private func smoothEase(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
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

            fitAIProgress = smoothEase(fitT)
            traditionalProgress = tradElapsed > 0 ? smoothEase(tradT) : 0

            let dotSpacing = dashPattern[0] + dashPattern[1]
            let totalLineLength: CGFloat = 400
            let totalDots = Int(totalLineLength / dotSpacing)
            let currentDot = Int(fitAIProgress * CGFloat(totalDots))
            if currentDot > lastHapticBucket {
                lastHapticBucket = currentDot
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
