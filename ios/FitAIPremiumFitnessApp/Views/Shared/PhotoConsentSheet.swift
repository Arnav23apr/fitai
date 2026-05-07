import SwiftUI

/// Pre-camera explicit consent modal. Shown once per consent version
/// (bumped via `UserProfile.currentPhotoConsentVersion`) before the user's
/// first scan or first 1v1 photo upload, whichever comes first.
///
/// **Why this exists**: GDPR Art. 9(2)(a) requires explicit, unbundled,
/// affirmative consent for "special category data" (which includes
/// physique/biometric photos used for analysis). The Italian Garante
/// (Replika €5M) and Dutch DPA have explicitly held that bundling photo
/// consent into the ToS is invalid. This modal is the unbundled prompt.
///
/// **Design rules** (each matches a real enforcement decision):
/// - Required scan toggle + optional improvement toggle, NOT a single
///   "I agree" button (UK ICO 2024 dark-patterns guidance).
/// - The optional toggle is **default OFF** — pre-checked = invalid consent.
/// - Decline button must be visually equal to Continue (ICO).
/// - Plain-language summary above the legalese.
struct PhotoConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    /// Called with `true` if the user accepts, `false` if they decline.
    /// The caller decides what "decline" means (block scan, dismiss, etc.).
    var onResult: (Bool) -> Void

    @State private var scanConsent: Bool = false
    @State private var improvementOptIn: Bool = false
    @State private var hapticTrigger: Int = 0

    /// Tweak in lockstep with `UserProfile.currentPhotoConsentVersion`.
    private var policyURL: URL { LegalLinks.privacy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    bullets
                    toggles
                    legalLinkRow
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                buttonRow
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .background(.regularMaterial)
            }
            .navigationTitle("Photo consent")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled() // explicit choice required
        }
        .sensoryFeedback(.selection, trigger: hapticTrigger)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 30))
                .foregroundStyle(.primary)
                .padding(10)
                .background(Color.primary.opacity(0.06))
                .clipShape(Circle())
            Text("Before you scan")
                .font(.system(.title2, weight: .bold))
            Text("FitAI needs your permission to analyze your body photo. Here's exactly what happens to it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet(
                icon: "sparkles",
                tint: .blue,
                title: "What we do with it",
                text: "Your photo is sent over an encrypted connection to Google Gemini, which returns your physique score. We don't use your photos to train any AI."
            )
            bullet(
                icon: "clock.fill",
                tint: .orange,
                title: "How long we keep it",
                text: "Scan photos used purely for the score aren't stored. Photos used to generate your \"Future You\" image and 1v1 battle photos are deleted after 30 days (battles after 7)."
            )
            bullet(
                icon: "lock.fill",
                tint: .green,
                title: "Where it's stored",
                text: "Encrypted at rest on our servers (Supabase, US-East). Access is via short-lived signed URLs — even if a link leaks, it expires."
            )
            bullet(
                icon: "trash.fill",
                tint: .red,
                title: "Your control",
                text: "You can delete every photo and your full account from Settings → Privacy. Deletion completes within 30 days."
            )
        }
    }

    private func bullet(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your choices")
                .font(.caption.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            consentToggle(
                isOn: $scanConsent,
                title: "Analyze my body photo",
                subtitle: "Required to use the scan, plan, and battle features.",
                required: true
            )
            consentToggle(
                isOn: $improvementOptIn,
                title: "Help improve FitAI (optional)",
                subtitle: "Anonymized scan stats only — never your photo or identity.",
                required: false
            )
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func consentToggle(
        isOn: Binding<Bool>,
        title: String,
        subtitle: String,
        required: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if required {
                        Text("REQUIRED")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.14))
                            .clipShape(.capsule)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
                .onChange(of: isOn.wrappedValue) { _, _ in hapticTrigger += 1 }
        }
    }

    private var legalLinkRow: some View {
        Button {
            openURL(policyURL)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11, weight: .semibold))
                Text("Read the full privacy policy")
                    .font(.caption.weight(.medium))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.secondary)
        }
    }

    private var buttonRow: some View {
        HStack(spacing: 10) {
            Button {
                onResult(false)
                dismiss()
            } label: {
                Text("Decline")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 14))
            }
            Button {
                appState.profile.photoConsentVersion = UserProfile.currentPhotoConsentVersion
                appState.profile.photoConsentGrantedAt = Date()
                appState.profile.photoImprovementOptIn = improvementOptIn
                appState.saveProfile()
                onResult(true)
                dismiss()
            } label: {
                Text("Continue")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(scanConsent ? Color.primary : Color.primary.opacity(0.25))
                    .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(!scanConsent)
        }
    }
}
