import SwiftUI

struct ConfidenceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var selectedValue: Int = 5
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("trainingConfidence", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("confidence", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("howExperienced", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 32) {
                Text("\(selectedValue)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(selectedValue)))
                    .animation(.snappy, value: selectedValue)

                VStack(spacing: 8) {
                    Text(confidenceLabel)
                        .font(.headline)
                        .foregroundStyle(.primary.opacity(0.8))
                    Text(confidenceDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: selectedValue)

                HStack(spacing: 6) {
                    ForEach(1...10, id: \.self) { value in
                        Button(action: {
                            selectedValue = value
                        }) {
                            Text("\(value)")
                                .font(.system(.callout, weight: .semibold))
                                .foregroundStyle(value == selectedValue ? (isDark ? .black : .white) : .secondary)
                                .frame(width: 34, height: 34)
                                .background(value == selectedValue ? (isDark ? Color.white : Color.black) : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                                .clipShape(Circle())
                        }
                        .sensoryFeedback(.selection, trigger: selectedValue)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()

            Button(action: {
                appState.profile.trainingConfidence = selectedValue
                onContinue()
            }) {
                Text(L.t("continue", lang))
                    .font(.headline)
                    .foregroundStyle(isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(.rect(cornerRadius: 16))
            }
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

    private var confidenceLabel: String {
        switch selectedValue {
        case 1...3: return L.t("beginner", appState.profile.selectedLanguage)
        case 4...6: return L.t("intermediate", appState.profile.selectedLanguage)
        case 7...9: return L.t("advanced", appState.profile.selectedLanguage)
        case 10: return L.t("expert", appState.profile.selectedLanguage)
        default: return ""
        }
    }

    private var confidenceDescription: String {
        switch selectedValue {
        case 1...3: return L.t("justGettingStarted", appState.profile.selectedLanguage)
        case 4...6: return L.t("knowBasicsWell", appState.profile.selectedLanguage)
        case 7...9: return L.t("yearsOfExperience", appState.profile.selectedLanguage)
        case 10: return L.t("competitiveAthleteLevel", appState.profile.selectedLanguage)
        default: return ""
        }
    }
}
