import SwiftUI

struct DateOfBirthView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let min = calendar.date(byAdding: .year, value: -80, to: Date()) ?? Date()
        let max = calendar.date(byAdding: .year, value: -13, to: Date()) ?? Date()
        return min...max
    }()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("whenWere", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(L.t("youBorn", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text(L.t("helpsPersonalize", lang))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            VStack(spacing: 24) {
                Text(formattedAge)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(L.t("yearsOld", lang))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.5))

                DatePicker("", selection: $selectedDate, in: dateRange, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 180)
                    .colorScheme(.dark)
                    .padding(.horizontal, 16)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
            Spacer()

            Button(action: {
                appState.profile.dateOfBirth = selectedDate
                onContinue()
            }) {
                Text(L.t("continue", lang))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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
