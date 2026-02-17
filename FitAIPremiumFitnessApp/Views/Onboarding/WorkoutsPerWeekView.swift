import SwiftUI

struct WorkoutsPerWeekView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void
    @State private var selected: Int = 3
    @State private var appeared: Bool = false

    private var lang: String { appState.profile.selectedLanguage }
    private var isDark: Bool { colorScheme == .dark }

    private var options: [(count: Int, key: String)] {
        [
            (1, "justStarting"),
            (2, "casual"),
            (3, "moderate"),
            (4, "dedicated"),
            (5, "intense"),
            (6, "athlete"),
            (7, "everyDay")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(L.t("howManyTimes", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("perWeek", lang))
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L.t("howOftenTrain", lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 24) {
                Text("\(selected)x")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(selected)))
                    .animation(.snappy, value: selected)

                Text(options.first(where: { $0.count == selected }).map { L.t($0.key, lang) } ?? "")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: selected)

                HStack(spacing: 8) {
                    ForEach(options, id: \.count) { option in
                        Button {
                            selected = option.count
                        } label: {
                            Text("\(option.count)")
                                .font(.system(.callout, weight: .semibold))
                                .foregroundStyle(option.count == selected ? (isDark ? .black : .white) : .secondary)
                                .frame(width: 40, height: 40)
                                .background(option.count == selected ? (isDark ? Color.white : Color.black) : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                                .clipShape(Circle())
                        }
                        .sensoryFeedback(.selection, trigger: selected)
                    }
                }
            }
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()

            Button(action: {
                appState.profile.workoutsPerWeek = selected
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
}
