import SwiftUI

struct EditWorkoutPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var primaryGoal: String = ""
    @State private var selectedGoals: Set<String> = []
    @State private var workoutsPerWeek: Int = 3
    @State private var trainingExperience: String = ""
    @State private var trainingLocation: String = ""
    @State private var selectedEquipment: Set<String> = []

    private let equipmentOptions: [(icon: String, label: String, useCustomIcon: Bool)] = [
        ("dumbbell.fill", "Dumbbells", false),
        ("", "Pull-up Bar", true),
        ("figure.walk", "Bodyweight Only", false),
    ]

    private var showEquipment: Bool {
        trainingLocation == "Home" || trainingLocation == "Both"
    }

    private var lang: String { appState.profile.selectedLanguage }

    private let primaryGoalOptions: [(icon: String, labelKey: String, descKey: String, value: String)] = [
        ("figure.strengthtraining.traditional", "buildMuscle", "gainSizeStrength", "Build Muscle"),
        ("flame.fill", "loseFat", "leanDownCut", "Lose Fat"),
        ("arrow.triangle.2.circlepath", "recomp", "buildMuscleLoseFat", "Recomp"),
    ]

    private let specificGoalOptions: [String] = [
        "Build muscle", "Lose fat",
        "Get stronger", "Improve endurance",
        "Better posture", "Increase flexibility",
        "Run a marathon", "Feel more confident",
        "Build a routine", "Compete in fitness",
    ]

    private let experienceOptions: [(icon: String, titleKey: String, subtitleKey: String, value: String)] = [
        ("leaf", "beginner", "lessThan6Months", "Beginner"),
        ("flame", "intermediate", "sixMonthsTo2Years", "Intermediate"),
        ("bolt.fill", "advanced", "twoYearsPlus", "Advanced"),
        ("trophy.fill", "expert", "competitiveLevel", "Expert"),
    ]

    private let locationOptions: [(icon: String, labelKey: String, descKey: String, value: String)] = [
        ("building.2", "gym", "fullEquipment", "Gym"),
        ("house", "home", "bodyweightMinimal", "Home"),
        ("figure.mixed.cardio", "both", "mixGymHome", "Both"),
    ]

    private let weeklyCountKeys: [Int: String] = [
        1: "justStarting", 2: "casual", 3: "moderate",
        4: "dedicated", 5: "intense", 6: "athlete", 7: "everyDay",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    primaryGoalCard
                    specificGoalsCard
                    workoutsPerWeekCard
                    experienceCard
                    locationCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .navigationTitle(L.t("workoutPreferences", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", lang)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save", lang)) { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            primaryGoal = appState.profile.primaryGoal
            selectedGoals = Set(appState.profile.goals)
            workoutsPerWeek = max(1, min(7, appState.profile.workoutsPerWeek))
            trainingExperience = appState.profile.trainingExperience
            trainingLocation = appState.profile.trainingLocation
            selectedEquipment = Set(appState.profile.availableEquipment)
        }
    }

    // MARK: - Cards

    private var primaryGoalCard: some View {
        groupCard(title: L.t("primaryGoal", lang)) {
            VStack(spacing: 8) {
                ForEach(primaryGoalOptions, id: \.value) { option in
                    listRow(
                        icon: option.icon,
                        title: L.t(option.labelKey, lang),
                        subtitle: L.t(option.descKey, lang),
                        isSelected: primaryGoal == option.value
                    ) {
                        primaryGoal = option.value
                    }
                }
            }
        }
    }

    private var specificGoalsCard: some View {
        groupCard(title: L.t("specificGoals", lang)) {
            FlowLayout(spacing: 8) {
                ForEach(specificGoalOptions, id: \.self) { goal in
                    let isSelected = selectedGoals.contains(goal)
                    Button {
                        if isSelected { selectedGoals.remove(goal) } else { selectedGoals.insert(goal) }
                    } label: {
                        Text(goal)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(isSelected ? Color.primary : Color.primary.opacity(0.05))
                            .clipShape(Capsule())
                    }
                    .sensoryFeedback(.selection, trigger: isSelected)
                }
            }
        }
    }

    private var workoutsPerWeekCard: some View {
        groupCard(title: L.t("schedule", lang)) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(workoutsPerWeek)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: Double(workoutsPerWeek)))
                        .animation(.snappy, value: workoutsPerWeek)
                    Text("× / week")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let key = weeklyCountKeys[workoutsPerWeek] {
                        Text(L.t(key, lang))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.07))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { count in
                        Button {
                            workoutsPerWeek = count
                        } label: {
                            Text("\(count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(count == workoutsPerWeek ? Color(.systemBackground) : .secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(count == workoutsPerWeek ? Color.primary : Color.primary.opacity(0.06))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        .sensoryFeedback(.selection, trigger: workoutsPerWeek)
                    }
                }
            }
        }
    }

    private var experienceCard: some View {
        groupCard(title: L.t("trainingExperienceTitle", lang)) {
            VStack(spacing: 8) {
                ForEach(experienceOptions, id: \.value) { option in
                    listRow(
                        icon: option.icon,
                        title: L.t(option.titleKey, lang),
                        subtitle: L.t(option.subtitleKey, lang),
                        isSelected: trainingExperience == option.value
                    ) {
                        trainingExperience = option.value
                    }
                }
            }
        }
    }

    private var locationCard: some View {
        groupCard(title: L.t("whereYouTrain", lang)) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(locationOptions, id: \.value) { option in
                        let isSelected = trainingLocation == option.value
                        Button {
                            withAnimation(.snappy(duration: 0.3)) {
                                trainingLocation = option.value
                                if option.value == "Gym" {
                                    selectedEquipment = []
                                }
                            }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: option.icon)
                                    .font(.system(size: 24))
                                    .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
                                Text(L.t(option.labelKey, lang))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 84)
                            .background(isSelected ? Color.primary : Color.primary.opacity(0.05))
                            .clipShape(.rect(cornerRadius: 14))
                        }
                        .sensoryFeedback(.selection, trigger: trainingLocation)
                    }
                }

                if showEquipment {
                    equipmentSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t("availableEquipment", lang))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                ForEach(equipmentOptions, id: \.label) { eq in
                    let isSelected = selectedEquipment.contains(eq.label)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            if isSelected {
                                selectedEquipment.remove(eq.label)
                            } else {
                                selectedEquipment.insert(eq.label)
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            if eq.useCustomIcon {
                                PullUpBarIcon(color: isSelected ? Color(.systemBackground) : .secondary)
                                    .frame(width: 28, height: 24)
                            } else {
                                Image(systemName: eq.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
                            }
                            Text(eq.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(isSelected ? Color.primary : Color.primary.opacity(0.05))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(isSelected ? Color.primary.opacity(0.25) : .clear, lineWidth: 1)
                        )
                    }
                    .sensoryFeedback(.selection, trigger: selectedEquipment)
                }
            }
        }
    }

    // MARK: - Reusable

    @ViewBuilder
    private func groupCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    @ViewBuilder
    private func listRow(icon: String, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(isSelected ? Color(.systemBackground) : .secondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color(.systemBackground).opacity(0.7) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.systemBackground))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(isSelected ? Color.primary : Color.primary.opacity(0.04))
            .clipShape(.rect(cornerRadius: 12))
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private func save() {
        appState.profile.primaryGoal = primaryGoal
        appState.profile.goals = Array(selectedGoals)
        appState.profile.workoutsPerWeek = workoutsPerWeek
        appState.profile.trainingExperience = trainingExperience
        appState.profile.trainingLocation = trainingLocation
        appState.profile.availableEquipment = showEquipment ? Array(selectedEquipment) : []
        appState.saveProfile()
        dismiss()
    }
}
