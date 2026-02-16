import SwiftUI

struct WorkoutsPerWeekView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var selected: Int = 3
    @State private var appeared: Bool = false

    private let options: [(count: Int, label: String)] = [
        (1, "Just starting"),
        (2, "Casual"),
        (3, "Moderate"),
        (4, "Dedicated"),
        (5, "Intense"),
        (6, "Athlete"),
        (7, "Every day")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("How many times")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("per week?")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("How often do you want to train")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 24) {
                Text("\(selected)x")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(selected)))
                    .animation(.snappy, value: selected)

                Text(options.first(where: { $0.count == selected })?.label ?? "")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))
                    .animation(.easeInOut(duration: 0.2), value: selected)

                HStack(spacing: 8) {
                    ForEach(options, id: \.count) { option in
                        Button {
                            selected = option.count
                        } label: {
                            Text("\(option.count)")
                                .font(.system(.callout, weight: .semibold))
                                .foregroundStyle(option.count == selected ? .black : .white.opacity(0.7))
                                .frame(width: 40, height: 40)
                                .background(option.count == selected ? Color.white : Color.white.opacity(0.08))
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
                Text("Continue")
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
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}
