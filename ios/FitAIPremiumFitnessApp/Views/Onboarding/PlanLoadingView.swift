import SwiftUI

/// Engineered "AI is building your plan" moment. A sequential checklist
/// fakes computational effort so the plan preview that follows feels
/// earned. Norton/Mochon/Ariely's effort heuristic — perceived effort
/// raises perceived value of an identical deliverable by ~20%.
///
/// Total run length: ~6.5 seconds across 5 checkpoints. Auto-advances.
struct PlanLoadingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var stepIndex: Int = 0
    @State private var headerAppeared: Bool = false
    @State private var ringRotation: Double = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private var checklist: [String] {
        [
            L.t("planLoadingStep1", lang),
            L.t("planLoadingStep2", lang),
            L.t("planLoadingStep3", lang),
            L.t("planLoadingStep4", lang),
            L.t("planLoadingStep5", lang),
        ]
    }

    /// Per-step duration in seconds. First steps are faster, last is slower
    /// so the user feels the pace decelerate as the "hard work" wraps up.
    private let stepDurations: [Double] = [0.9, 1.1, 1.3, 1.4, 1.6]

    var body: some View {
        ZStack {
            AuroraBackground(
                colors: [
                    Color.blue.opacity(isDark ? 0.10 : 0.05),
                    Color.indigo.opacity(isDark ? 0.08 : 0.04),
                    Color.purple.opacity(isDark ? 0.06 : 0.03),
                    Color.clear,
                    Color.clear,
                ],
                speed: 0.14
            )

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                heroSpinner
                    .padding(.bottom, 36)

                VStack(spacing: 6) {
                    Text(L.t("planLoadingTitle", lang))
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(L.t("planLoadingSubtitle", lang))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : 12)

                checklistSection
                    .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
        }
        .onAppear { runChoreography() }
    }

    // MARK: - Hero spinner (concentric rings, slow rotation)

    private var heroSpinner: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                .frame(width: 140, height: 140)

            Circle()
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                .frame(width: 110, height: 110)

            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color.primary.opacity(0.18), Color.primary.opacity(0.40), Color.primary],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 84, height: 84)
                .rotationEffect(.degrees(ringRotation))

            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.primary)
                .symbolEffect(.pulse.byLayer, options: .repeating)
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(checklist.enumerated()), id: \.offset) { idx, line in
                checklistRow(text: line, state: state(for: idx))
                    .opacity(idx <= stepIndex ? 1 : 0.35)
            }
        }
    }

    private enum RowState { case pending, active, done }

    private func state(for idx: Int) -> RowState {
        if idx < stepIndex { return .done }
        if idx == stepIndex { return .active }
        return .pending
    }

    @ViewBuilder
    private func checklistRow(text: String, state: RowState) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.75)
                    .frame(width: 22, height: 22)

                switch state {
                case .pending:
                    EmptyView()
                case .active:
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .frame(width: 22, height: 22)
                        .rotationEffect(.degrees(ringRotation * 2))
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }

            Text(text)
                .font(.system(.subheadline, weight: state == .pending ? .regular : .medium))
                .foregroundStyle(state == .pending ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.snappy(duration: 0.3), value: state)
    }

    // MARK: - Choreography

    private func runChoreography() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
            headerAppeared = true
        }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        var elapsed: Double = 0.5
        for i in 0..<checklist.count {
            let dur = stepDurations[safe: i] ?? 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + elapsed) {
                withAnimation(.snappy) {
                    stepIndex = i + 1
                }
            }
            elapsed += dur
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + elapsed + 0.4) {
            onContinue()
        }
    }
}

// Array.subscript(safe:) is defined module-wide in PlanView.swift —
// duplicate private extension here was tripping the Swift compiler's
// "invalid redeclaration" check against the internal-scoped definition.
