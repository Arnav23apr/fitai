import SwiftUI

struct ChallengeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: FriendViewModel
    let friend: Friend
    @State private var selectedCategory: String = "Physique Battle"
    @State private var isSending: Bool = false
    @State private var sent: Bool = false
    @State private var hapticTrigger: Int = 0

    private let categories = [
        ("Physique Battle", "figure.mixed.cardio", "Upload photos, AI judges"),
        ("Workout Streak", "flame.fill", "Longest streak wins"),
        ("XP Race", "bolt.fill", "Most XP in 7 days"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        versusHeader

                        categoryPicker

                        rulesCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                sendButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("1v1 Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: hapticTrigger)
        }
    }

    private var versusHeader: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                }
                Text("You")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity)

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 44, height: 44)
                Text("VS")
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(.red)
            }

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tierColor(friend.tier).opacity(0.12))
                        .frame(width: 64, height: 64)
                    Text(friend.avatarEmoji)
                        .font(.system(size: 28))
                }
                Text(friend.displayName)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(tierColor(friend.tier))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.04), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(.rect(cornerRadius: 20))
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHALLENGE TYPE")
                .font(.system(.caption2, design: .rounded, weight: .black))
                .tracking(1.5)
                .foregroundStyle(.secondary)

            ForEach(categories, id: \.0) { category in
                let isSelected = selectedCategory == category.0
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedCategory = category.0
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.red.opacity(0.12) : Color(.systemGray5))
                                .frame(width: 44, height: 44)
                            Image(systemName: category.1)
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? .red : .secondary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.0)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(category.2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        ZStack {
                            Circle()
                                .strokeBorder(isSelected ? Color.red : Color(.systemGray4), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if isSelected {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                    .padding(14)
                    .background(isSelected ? Color.red.opacity(0.04) : Color(.secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
                Text("HOW IT WORKS")
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .tracking(1)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {
                ruleRow("1", "Challenge is sent to \(friend.displayName)")
                ruleRow("2", "Both players upload their photos")
                ruleRow("3", "AI analyzes and scores both physiques")
                ruleRow("4", "Winner earns +75 XP, loser gets +25 XP")
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func ruleRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(.blue.opacity(0.5))
                .frame(width: 18)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sendButton: some View {
        Button {
            sendChallenge()
        } label: {
            Group {
                if isSending {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Sending...")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                } else if sent {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Challenge Sent!")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Send Challenge")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(sent ? Color.green : Color.red)
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(isSending || sent)
    }

    private func sendChallenge() {
        isSending = true
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            viewModel.sendChallenge(to: friend, category: selectedCategory)
            isSending = false
            sent = true
            hapticTrigger += 1
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        }
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "Silver": return Color(red: 0.75, green: 0.75, blue: 0.80)
        case "Gold": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "Platinum": return Color(red: 0.6, green: 0.8, blue: 0.95)
        case "Diamond": return Color(red: 0.7, green: 0.85, blue: 1.0)
        default: return Color(red: 0.80, green: 0.50, blue: 0.20)
        }
    }
}
