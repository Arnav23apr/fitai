import SwiftUI

/// Compact "Unlock unlimited history" card. Drop in below any
/// history chart, list, or insight that's been truncated to the
/// free 30-day window. Tap opens the standard paywall sheet.
///
/// Usage:
/// ```swift
/// if !appState.profile.isPremium, hiddenCount > 0 {
///     LockedHistoryCard(hiddenCount: hiddenCount)
/// }
/// ```
struct LockedHistoryCard: View {
    @Environment(AppState.self) private var appState
    /// Number of older entries the user can't see. Surfaced in the
    /// copy so the upsell feels concrete ("12 more sessions") not
    /// generic ("more history available").
    var hiddenCount: Int? = nil
    /// Override the headline if the host surface has a more
    /// specific frame ("Unlock 6 months of volume data").
    var headline: String? = nil

    @State private var showPaywall: Bool = false

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.78, blue: 0.20).opacity(0.18),
                                    Color(red: 1.00, green: 0.55, blue: 0.10).opacity(0.06),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.88, blue: 0.28),
                                    Color(red: 1.00, green: 0.55, blue: 0.10),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline ?? defaultHeadline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subhead)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.88, blue: 0.28).opacity(0.35),
                                Color(red: 1.00, green: 0.55, blue: 0.10).opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallSheet(context: .profile)
        }
    }

    private var defaultHeadline: String {
        "Unlock unlimited history"
    }

    private var subhead: String {
        if let count = hiddenCount, count > 0 {
            return "You have \(count) older session\(count == 1 ? "" : "s") locked. Pro unlocks all of them."
        }
        return "Free tier shows the last 30 days. Pro keeps every session forever."
    }
}
