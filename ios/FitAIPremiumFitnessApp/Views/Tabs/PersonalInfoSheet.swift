import SwiftUI

/// Lets the user edit profile data that's collected in onboarding but
/// otherwise un-editable post-onboarding: date of birth and gender. Both
/// feed `ProfileContextBuilder` (which informs AI scan + plan output) and
/// the gender-targeted onboarding copy (HardTruth, OnePercent), so users
/// who picked the wrong option during signup need a way to fix it.
///
/// Height/weight live in `BodyMeasurementsSheet`. Goal/experience/equipment
/// live in `EditWorkoutPreferencesSheet`. Name/username/photo live in
/// `EditProfileSheet`. This sheet covers what the other three don't.
///
/// Visual language mirrors `EditWorkoutPreferencesSheet` (card-based,
/// hero numeric + selection rows) so the two settings sheets feel like
/// siblings rather than belonging to different apps.
struct PersonalInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Local working copy, flushed back to `appState.profile` on Save so
    /// cancelling mid-edit doesn't dirty the persisted profile.
    @State private var dateOfBirth: Date = Date()
    @State private var hasDateOfBirth: Bool = false
    @State private var gender: String = ""

    private var lang: String { appState.profile.selectedLanguage }

    /// 13+ matches the App Store age gating and our existing onboarding floor.
    /// 120 is a safe upper bound for the picker, capping the wheel without
    /// being insultingly low.
    private var dobRange: ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        let oldest = cal.date(byAdding: .year, value: -120, to: now) ?? now
        let youngest = cal.date(byAdding: .year, value: -13, to: now) ?? now
        return oldest...youngest
    }

    private var computedAge: Int? {
        guard hasDateOfBirth else { return nil }
        let comps = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date())
        return comps.year
    }

    private let genderOptions: [(value: String, title: String, subtitle: String, icon: String)] = [
        ("male", "Male", "Mass + V-taper emphasis on scans", "figure.stand"),
        ("female", "Female", "Glutes + hip-to-waist focus on scans", "figure.stand.dress")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    dobCard
                    genderCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .navigationTitle("Personal Info")
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
            if let dob = appState.profile.dateOfBirth {
                dateOfBirth = dob
                hasDateOfBirth = true
            } else {
                // Seed at 25 years ago, the most-likely target-user age,
                // so the picker wheel doesn't open at "today" and feel
                // like a long scroll.
                dateOfBirth = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
            }
            gender = appState.profile.gender
        }
    }

    // MARK: - Cards

    private var dobCard: some View {
        groupCard(title: "Age") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let age = computedAge {
                        Text("\(age)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: Double(age)))
                            .animation(reduceMotion ? nil : .snappy, value: age)
                        Text(age == 1 ? "year old" : "years old")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                        Text("Pick your birth date")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                DatePicker(
                    "Date of birth",
                    selection: Binding(
                        get: { dateOfBirth },
                        set: { newValue in
                            dateOfBirth = newValue
                            if !hasDateOfBirth { hasDateOfBirth = true }
                        }
                    ),
                    in: dobRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Calibrates scan analysis and plan recommendations. Stays on-device unless you sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var genderCard: some View {
        groupCard(title: "Gender") {
            VStack(spacing: 8) {
                ForEach(genderOptions, id: \.value) { option in
                    listRow(
                        icon: option.icon,
                        title: option.title,
                        subtitle: option.subtitle,
                        isSelected: gender.lowercased() == option.value
                    ) {
                        gender = option.value
                    }
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
            .frame(minHeight: 56)
            .background(isSelected ? Color.primary : Color.primary.opacity(0.04))
            .clipShape(.rect(cornerRadius: 12))
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private func save() {
        appState.profile.dateOfBirth = hasDateOfBirth ? dateOfBirth : nil
        appState.profile.gender = gender
        appState.saveProfile()
        dismiss()
    }
}
