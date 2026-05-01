import SwiftUI
import UIKit

struct PlanPreviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var appeared: Bool = false
    @State private var dumbbellSettled: Bool = false
    @State private var glowPulse: CGFloat = 0.85
    @State private var rowsRevealed: Int = 0
    @State private var isGenerating: Bool = true
    @State private var showContent: Bool = false

    private let successHaptic = UINotificationFeedbackGenerator()

    private var isDark: Bool { colorScheme == .dark }

    private var weeklyWorkouts: Int {
        max(1, min(7, appState.profile.workoutsPerWeek))
    }

    private var goalText: String {
        let g = appState.profile.primaryGoal
        return g.isEmpty ? "Build your dream physique" : g
    }

    private var estimatedWeeks: Int {
        // Rough heuristic — more workouts/week = faster perceived progress.
        switch weeklyWorkouts {
        case 5...: return 8
        case 3...4: return 11
        default: return 14
        }
    }

    private var weakPointsLine: String {
        let pts = appState.profile.weakPoints
        if pts.isEmpty { return "Balanced full-body focus" }
        return pts.prefix(2).joined(separator: " · ")
    }

    private var planRows: [(icon: String, label: String, value: String)] {
        [
            ("dumbbell.fill",   "Workouts / week",   "\(weeklyWorkouts)"),
            ("target",          "Primary goal",      goalText),
            ("flame.fill",      "Weak-point focus",  weakPointsLine),
            ("calendar",        "Estimated timeline","\(estimatedWeeks) weeks"),
            ("sparkles",        "AI coach",          "Always on")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            dumbbellHero
                .padding(.top, 36)
                .padding(.bottom, 4)

            VStack(spacing: 10) {
                Text(isGenerating ? "Building your plan..." : "Your plan is ready")
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                Text(isGenerating ? "Analyzing your goals and physique data" : "Built around your scan, goals, and schedule.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)

            Spacer().frame(height: 28)

            if isGenerating {
                // Generating spinner
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.primary)
                    Text("Personalizing exercises, sets, and recovery...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
                .transition(.opacity)
            } else {
                planCard
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .offset(y: 16)))
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.primary)
                    .clipShape(.rect(cornerRadius: 28))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            successHaptic.prepare()
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            withAnimation(.spring(duration: 1.0, bounce: 0.25)) {
                dumbbellSettled = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = 1.15
            }

            // Phase 1: Show "generating" state for 3.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                successHaptic.notificationOccurred(.success)
                withAnimation(.spring(duration: 0.5)) {
                    isGenerating = false
                }

                // Phase 2: Reveal rows one by one (staggered)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    revealRows()
                }

                // Phase 3: Show continue button after rows finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 0.25 + Double(planRows.count) * 0.18 + 0.3) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showContent = true
                    }
                }
            }
        }
    }

    // MARK: - Hero (3D dumbbell with pulsing glow)

    private var dumbbellHero: some View {
        ZStack {
            // Soft pulsing glow behind the dumbbell
            RadialGradient(
                colors: [
                    Color.primary.opacity(isDark ? 0.18 : 0.10),
                    Color.primary.opacity(0.0)
                ],
                center: .center,
                startRadius: 4,
                endRadius: 110
            )
            .frame(width: 220, height: 220)
            .scaleEffect(glowPulse)
            .opacity(dumbbellSettled ? 1 : 0)

            DumbbellSceneView(transparent: true, darkChrome: !isDark)
                .frame(width: 180, height: 180)
                .shadow(color: Color.primary.opacity(0.10), radius: 20, y: 8)
                .rotationEffect(.degrees(dumbbellSettled ? 0 : -90))
                .scaleEffect(dumbbellSettled ? 1 : 0.85)
                .opacity(dumbbellSettled ? 1 : 0)
                .allowsHitTesting(false)
        }
        .frame(height: 200)
    }

    // MARK: - Card

    private var planCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(planRows.enumerated()), id: \.offset) { idx, row in
                planRowView(row, index: idx)
                if idx < planRows.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isDark ? Color.white.opacity(0.05) : Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 18))
    }

    private func planRowView(_ row: (icon: String, label: String, value: String), index: Int) -> some View {
        let revealed = index < rowsRevealed
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: row.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
                .opacity(revealed ? 1 : 0)
                .scaleEffect(revealed ? 1 : 0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(revealed ? 1 : 0.25)
        .animation(.snappy(duration: 0.35), value: revealed)
    }

    private func revealRows() {
        for i in 1...planRows.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.18) {
                withAnimation(.snappy(duration: 0.3)) {
                    rowsRevealed = i
                }
            }
        }
    }
}
