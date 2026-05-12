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
struct PersonalInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// Local working copy — flushed back to `appState.profile` on Save so
    /// cancelling mid-edit doesn't dirty the persisted profile.
    @State private var dateOfBirth: Date = Date()
    @State private var hasDateOfBirth: Bool = false
    @State private var gender: String = ""

    private var lang: String { appState.profile.selectedLanguage }

    private func genderRow(value: String, label: String, icon: String) -> some View {
        Button {
            gender = value
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                if gender.lowercased() == value {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 13+ matches the App Store age gating and our existing onboarding floor.
    /// 120 is a safe upper bound for the picker — it caps the wheel without
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if hasDateOfBirth {
                        DatePicker(
                            "Date of birth",
                            selection: $dateOfBirth,
                            in: dobRange,
                            displayedComponents: [.date]
                        )
                        if let age = computedAge {
                            HStack {
                                Text("Age")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(age)")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        Button(role: .destructive) {
                            hasDateOfBirth = false
                        } label: {
                            Text("Clear date of birth")
                        }
                    } else {
                        Button {
                            // Default to 25 years ago — most-likely target user
                            // age. Better than seeding "today" which makes the
                            // wheel scroll feel like a lot of work.
                            let cal = Calendar.current
                            dateOfBirth = cal.date(byAdding: .year, value: -25, to: Date()) ?? Date()
                            hasDateOfBirth = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Add date of birth")
                            }
                        }
                    }
                } header: {
                    Text("Age")
                } footer: {
                    Text("Used to calibrate scan analysis and plan recommendations. Stays on-device unless you sync.")
                }

                Section {
                    genderRow(value: "male", label: "Male", icon: "figure.stand")
                    genderRow(value: "female", label: "Female", icon: "figure.stand.dress")
                } header: {
                    Text("Gender")
                } footer: {
                    Text("Affects scan emphasis (e.g., glutes for female users) and the framing of motivational copy.")
                }
            }
            .navigationTitle("Personal Info")
            .navigationBarTitleDisplayMode(.inline)
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
            }
            gender = appState.profile.gender
        }
    }

    private func save() {
        appState.profile.dateOfBirth = hasDateOfBirth ? dateOfBirth : nil
        appState.profile.gender = gender
        appState.saveProfile()
        dismiss()
    }
}
