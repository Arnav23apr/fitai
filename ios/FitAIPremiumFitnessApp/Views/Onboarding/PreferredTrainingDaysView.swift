import SwiftUI

/// Asks the user which days of the week they prefer to train. Comes
/// right after `WorkoutsPerWeekView` so the AI plan generator can match
/// the user's preferred cadence to their schedule. Stored as 3-letter
/// uppercase day labels ("MON", "TUE", …) on `UserProfile.preferredTrainingDays`.
struct PreferredTrainingDaysView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var selected: Set<String> = []
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    /// Ordered Mon-first to match the rest of the app's weekly UI
    /// (weeklyStreakSection, etc.). Tuple is (storage key, short label,
    /// full label) so the storage stays compact while the chip can show
    /// the full day name.
    private let days: [(key: String, short: String, long: String)] = [
        ("MON", "Mon", "Monday"),
        ("TUE", "Tue", "Tuesday"),
        ("WED", "Wed", "Wednesday"),
        ("THU", "Thu", "Thursday"),
        ("FRI", "Fri", "Friday"),
        ("SAT", "Sat", "Saturday"),
        ("SUN", "Sun", "Sunday")
    ]

    private var target: Int {
        max(1, min(7, appState.profile.workoutsPerWeek))
    }

    /// Continue is disabled until the user has chosen exactly enough days
    /// to match their stated weekly volume. Picking fewer would silently
    /// reduce the plan; picking more would overshoot. This keeps the data
    /// internally consistent.
    private var canContinue: Bool {
        selected.count == target
    }

    private var helperText: String {
        if selected.count < target {
            let remaining = target - selected.count
            return remaining == 1
                ? "Pick 1 more day"
                : "Pick \(remaining) more days"
        } else if selected.count == target {
            return "Looks good. Tap continue."
        } else {
            return "Picked \(selected.count) of \(target). Remove some."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Which days work")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text("for you?")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Pick \(target) day\(target == 1 ? "" : "s") that fit your schedule")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    ForEach(days, id: \.key) { day in
                        dayRow(day)
                    }
                }
                .padding(.horizontal, 24)

                Text(helperText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(canContinue ? .green : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: helperText)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                appState.profile.preferredTrainingDays = days
                    .map(\.key)
                    .filter { selected.contains($0) }
                onContinue()
            }) {
                Text(L.t("continue", lang))
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canContinue ? Color.primary : Color.primary.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            // Pre-fill if returning to this step (back nav).
            if let saved = appState.profile.preferredTrainingDays {
                selected = Set(saved)
            }
        }
    }

    private func dayRow(_ day: (key: String, short: String, long: String)) -> some View {
        let isSelected = selected.contains(day.key)
        return Button {
            toggle(day.key)
        } label: {
            HStack(spacing: 14) {
                Text(day.short.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.primary : Color.primary.opacity(0.08))
                    )

                Text(day.long)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.primary.opacity(0.25) : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.0 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private func toggle(_ key: String) {
        if selected.contains(key) {
            selected.remove(key)
        } else {
            // Allow over-selection but cap at 7. Helper text guides them
            // back to `target` before continue enables.
            if selected.count >= 7 { return }
            selected.insert(key)
        }
    }
}
