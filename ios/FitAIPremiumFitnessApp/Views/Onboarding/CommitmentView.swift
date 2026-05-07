import SwiftUI

/// Pseudo-contract / commitment statement. Right before the plan reveal,
/// the user explicitly agrees to the three terms of their plan. Cialdini
/// commitment-and-consistency: people who explicitly commit have ~30%
/// higher 30-day retention than those who passively progress.
///
/// Each line auto-fills with the user's actual data (workouts/week and
/// training location) so the contract feels personal, not boilerplate.
struct CommitmentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var headerAppeared: Bool = false
    @State private var checked: [Bool] = [false, false, false]
    @State private var ctaAppeared: Bool = false
    @State private var ctaTapCount: Int = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private var lines: [String] {
        let perWeek = "\(appState.profile.workoutsPerWeek)"
        let location = appState.profile.trainingLocation.isEmpty
            ? L.t("workout", lang).lowercased()
            : appState.profile.trainingLocation.lowercased()
        return [
            String(format: L.t("commitLine1", lang), perWeek),
            String(format: L.t("commitLine2", lang), location),
            L.t("commitLine3", lang),
        ]
    }

    var body: some View {
        ZStack {
            AuroraBackground(
                colors: [
                    Color.green.opacity(isDark ? 0.10 : 0.05),
                    Color.cyan.opacity(isDark ? 0.06 : 0.03),
                    Color.blue.opacity(isDark ? 0.06 : 0.03),
                    Color.clear,
                    Color.clear,
                ],
                speed: 0.10
            )

            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 56)
                    .padding(.bottom, 36)

                Spacer(minLength: 0)

                contractCard
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                ctaButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .onAppear { runChoreography() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            let name = appState.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = name.isEmpty
                ? L.t("commitTitle", lang)
                : "\(name), \(L.t("commitTitle", lang).lowercased())"

            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Text(L.t("commitSubtitle", lang))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 12)
    }

    // MARK: - Contract

    private var contractCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                contractRow(text: line, checked: checked[safeIdx: idx] ?? false)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(isDark ? Color.white.opacity(0.05) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(isDark ? 0 : 0.06), radius: 16, y: 6)
    }

    private func contractRow(text: String, checked: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: 26, height: 26)
                if checked {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 26, height: 26)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: checked)

            Text(text)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            ctaTapCount += 1
            // Tiny delay so the haptic fires before we navigate away.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                onContinue()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                Text(L.t("commitButton", lang))
                    .font(.system(.headline, weight: .bold))
            }
            .foregroundStyle(Color(.systemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.primary)
            .clipShape(.rect(cornerRadius: 28))
            .shadow(color: .black.opacity(isDark ? 0 : 0.18), radius: 14, y: 6)
        }
        .opacity(ctaAppeared ? 1 : 0)
        .scaleEffect(ctaAppeared ? 1 : 0.94)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: headerAppeared)
        .sensoryFeedback(.selection, trigger: checked)
        .sensoryFeedback(.success, trigger: ctaTapCount)
    }

    // MARK: - Choreography

    private func runChoreography() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
            headerAppeared = true
        }

        // Stagger-check each commitment line so the user "watches"
        // themselves agree — a subtle commitment-and-consistency cue.
        for i in 0..<checked.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(i) * 0.35) {
                if checked.indices.contains(i) {
                    checked[i] = true
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(checked.count) * 0.35 + 0.25) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                ctaAppeared = true
            }
        }
    }
}

private extension Array {
    subscript(safeIdx index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
