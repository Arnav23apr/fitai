import SwiftUI

struct TrainingLocationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var selected: String = ""
    @State private var appeared: Bool = false
    @State private var selectedEquipment: Set<String> = []

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private var options: [(icon: String, labelKey: String, descKey: String, value: String)] {
        [
            ("building.2", "gym", "fullEquipment", "Gym"),
            ("house", "home", "bodyweightMinimal", "Home"),
            ("figure.mixed.cardio", "both", "mixGymHome", "Both")
        ]
    }

    private let equipmentOptions: [(icon: String, label: String, useCustomIcon: Bool)] = [
        ("dumbbell.fill", "Dumbbells", false),
        ("", "Pull-up Bar", true),
        ("figure.walk", "Bodyweight Only", false)
    ]

    private var showEquipment: Bool {
        selected == "Home" || selected == "Both"
    }

    private var canContinue: Bool {
        if selected.isEmpty { return false }
        if showEquipment && selectedEquipment.isEmpty { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("whereDoYou", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("youTrain", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 14) {
                ForEach(options, id: \.value) { option in
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            selected = option.value
                            if option.value == "Gym" {
                                selectedEquipment = []
                            }
                        }
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: option.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(selected == option.value ? Color(.systemBackground) : .secondary)
                            Text(L.t(option.labelKey, lang))
                                .font(.headline)
                                .foregroundStyle(selected == option.value ? Color(.systemBackground) : .primary)
                            Text(L.t(option.descKey, lang))
                                .font(.caption)
                                .foregroundStyle(selected == option.value ? Color(.systemBackground).opacity(0.6) : Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(selected == option.value ? Color.primary : Color.primary.opacity(0.05))
                        .clipShape(.rect(cornerRadius: 20))
                    }
                    .sensoryFeedback(.selection, trigger: selected)
                }

                if showEquipment {
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
                                            .strokeBorder(isSelected ? Color.primary.opacity(0.25) : Color.clear, lineWidth: 1)
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
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}
