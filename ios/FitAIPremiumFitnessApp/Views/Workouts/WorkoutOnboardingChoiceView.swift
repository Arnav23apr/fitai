import SwiftUI

/// First-run picker for the Workouts tab. Asks the user how they want to
/// operate: AI plan, custom templates, or paste an existing plan for
/// review. Saved to `profile.workoutMode`. Re-shown if the user resets the
/// mode from Profile → Settings.
struct WorkoutOnboardingChoiceView: View {
    @Environment(AppState.self) private var appState
    let onChoice: (UserProfile.WorkoutMode) -> Void

    @State private var appeared: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                    .padding(.top, 28)
                VStack(spacing: 12) {
                    choiceCard(
                        mode: .aiGenerated,
                        icon: "sparkles",
                        title: "Build me a plan",
                        subtitle: "I'll generate a 7-day program based on your goal, equipment, experience, and weak points.",
                        tag: "Recommended",
                        gradient: [.cyan, .blue]
                    )
                    choiceCard(
                        mode: .userBuilt,
                        icon: "list.bullet.rectangle.portrait",
                        title: "I'll build my own",
                        subtitle: "Skip the AI plan. Build templates from scratch, your splits, your way.",
                        tag: nil,
                        gradient: [.indigo, .purple]
                    )
                    choiceCard(
                        mode: .userPlanReviewed,
                        icon: "doc.text.magnifyingglass",
                        title: "Review my existing plan",
                        subtitle: "Paste your current program and I'll critique it, suggest tweaks, and import it for you.",
                        tag: appState.profile.isPremium ? nil : "Pro",
                        gradient: [.purple, .pink]
                    )
                }
                .padding(.horizontal, 18)

                footer
                    .padding(.bottom, 28)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(.spring(duration: 0.5, bounce: 0.18), value: appeared)
        }
        .background(Color(.systemBackground))
        .onAppear { appeared = true }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.30), .blue.opacity(0.10), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 70
                        )
                    )
                    .frame(width: 110, height: 110)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                    )
            }
            Text("How do you train?")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Pick the way you want to use FitAI's Workouts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func choiceCard(
        mode: UserProfile.WorkoutMode,
        icon: String,
        title: String,
        subtitle: String,
        tag: String?,
        gradient: [Color]
    ) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            onChoice(mode)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.25) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                        )
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let tag {
                            Text(tag)
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(0.5)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                                )
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    Color.primary.opacity(0.04)
                    LinearGradient(
                        colors: [gradient[0].opacity(0.06), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(gradient[0].opacity(0.18), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Text("You can change this anytime in Profile → Settings.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
}
