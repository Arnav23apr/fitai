import SwiftUI

/// Coming-soon teaser features. Surface in the Workouts hub as locked cards;
/// tapping opens a sheet that captures intent ("Notify me") so we know
/// which feature to ship first.
enum ComingSoonFeature: String, Identifiable {
    case voice
    case photo
    case appleWatch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice: return "Voice Log"
        case .photo: return "Photo Log"
        case .appleWatch: return "Apple Watch"
        }
    }

    var icon: String {
        switch self {
        case .voice: return "waveform"
        case .photo: return "camera.fill"
        case .appleWatch: return "applewatch"
        }
    }

    var tint: Color {
        switch self {
        case .voice: return .purple
        case .photo: return .pink
        case .appleWatch: return .cyan
        }
    }

    var headline: String {
        switch self {
        case .voice: return "Just say your reps"
        case .photo: return "Snap the machine display"
        case .appleWatch: return "Log without your phone"
        }
    }

    var description: String {
        switch self {
        case .voice:
            return "Hands-free logging. Tell FitAI \"three sets of ten at one thirty-five\" and we'll fill in the rows for you."
        case .photo:
            return "Skip the typing. Take a photo of the weight selector or machine display and we'll read the number."
        case .appleWatch:
            return "Start workouts, log sets, and watch your rest timer right from your wrist. No phone needed."
        }
    }

    /// UserDefaults key where we record the user's "Notify me" interest.
    var notifyKey: String { "comingSoon_notify_\(rawValue)" }
}

struct ComingSoonSheet: View {
    @Environment(\.dismiss) private var dismiss
    let feature: ComingSoonFeature

    @State private var notified: Bool = UserDefaults.standard.bool(forKey: "comingSoon_notify_default")

    var body: some View {
        VStack(spacing: 22) {
            // Hero icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [feature.tint.opacity(0.30), feature.tint.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: feature.icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(feature.tint)
            }
            .padding(.top, 18)

            VStack(spacing: 8) {
                Text(feature.title)
                    .font(.title2.weight(.bold))
                Text(feature.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(feature.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                notified.toggle()
                UserDefaults.standard.set(notified, forKey: feature.notifyKey)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: notified ? "checkmark" : "bell.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(notified ? "We'll notify you" : "Notify me when it's ready")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(notified ? feature.tint : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(notified ? feature.tint.opacity(0.15) : feature.tint)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            Button("Maybe later") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 18)
        }
        .padding()
        .onAppear {
            notified = UserDefaults.standard.bool(forKey: feature.notifyKey)
        }
    }
}
