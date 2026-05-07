import SwiftUI

struct DateOfBirthView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    /// Hard 16+ floor. EU-DPA enforcement on Replika hinged on weak age
    /// gating, and our photo-consent flow processes special-category data
    /// — under 16 cannot validly consent under GDPR Art. 8 in most member
    /// states. A real DOB picker (not a "I am 16+" checkbox) is the
    /// difference between defensible and indefensible at the regulator.
    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let min = calendar.date(byAdding: .year, value: -80, to: Date()) ?? Date()
        let max = calendar.date(byAdding: .year, value: -16, to: Date()) ?? Date()
        return min...max
    }()

    private var ageInYears: Int {
        Calendar.current.dateComponents([.year], from: selectedDate, to: Date()).year ?? 0
    }

    private var isAgeValid: Bool { ageInYears >= 16 }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("whenWere", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("youBorn", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("helpsPersonalize", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            VStack(spacing: 24) {
                Text(formattedAge)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                Text(L.t("yearsOld", lang))
                    .font(.headline)
                    .foregroundStyle(.secondary)

                DatePicker("", selection: $selectedDate, in: dateRange, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)
                    .padding(.horizontal, 16)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
            Spacer()

            VStack(spacing: 10) {
                if !isAgeValid {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("FitAI is for users 16 and over.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(.rect(cornerRadius: 10))
                    .padding(.horizontal, 24)
                }
                Button(action: {
                    guard isAgeValid else { return }
                    appState.profile.dateOfBirth = selectedDate
                    onContinue()
                }) {
                    Text(L.t("continue", lang))
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isAgeValid ? Color.primary : Color.primary.opacity(0.25))
                        .clipShape(.rect(cornerRadius: 16))
                }
                .disabled(!isAgeValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            if let dob = appState.profile.dateOfBirth {
                selectedDate = dob
            }
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    private var formattedAge: String {
        let age = Calendar.current.dateComponents([.year], from: selectedDate, to: Date()).year ?? 0
        return "\(age)"
    }
}
