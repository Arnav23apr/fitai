import SwiftUI

/// Settings → Privacy → "Photos & Data". Shows exactly what the user has
/// stored on our servers right now, and lets them delete it. This satisfies
/// GDPR Art. 15 (right of access) and Art. 17 (right to erasure) as a single
/// in-app surface — and signals trust to privacy-skeptical users.
///
/// Lists photos from `goal_projections/sources/` (the "Future You" inputs)
/// and `challenge_photos/` (1v1 battle uploads). Local-only photos
/// (profile avatar, default battle photo) are listed separately and
/// deleted via the FileManager helpers on AppState.
struct PhotosAndDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var photos: [PhotoUploadService.StoredPhoto] = []
    @State private var isLoading: Bool = true
    @State private var isDeleting: Bool = false
    @State private var showConfirmDeleteAll: Bool = false
    @State private var lastDeletedCount: Int? = nil
    @State private var refreshTrigger: Int = 0

    private var lang: String { appState.profile.selectedLanguage }
    private var userId: String? { appState.currentUserIdPublic }

    private var goalProjectionPhotos: [PhotoUploadService.StoredPhoto] {
        photos.filter { $0.bucket == "goal_projections" }
    }
    private var challengePhotos: [PhotoUploadService.StoredPhoto] {
        photos.filter { $0.bucket == "challenge_photos" }
    }

    private var totalBytes: Int {
        photos.compactMap(\.sizeBytes).reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    summaryCard
                    serverSection
                    localSection
                    actionsSection
                    legalNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Photos & Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .task(id: refreshTrigger) { await load() }
            .confirmationDialog(
                "Delete all your photos?",
                isPresented: $showConfirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete \(photos.count) photo\(photos.count == 1 ? "" : "s")", role: .destructive) {
                    Task { await deleteAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every server-stored photo. Your scan history (scores, weak points) stays — those don't include images. Local photos on this iPhone (profile avatar, default battle photo) are kept; clear them with the buttons below.")
            }
        }
    }

    // MARK: - Sections

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                Text("YOUR DATA")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Counting your stored photos...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else {
                Text(summaryHeadline)
                    .font(.system(.title2, weight: .bold))
                Text(summarySub)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.06), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
    }

    private var summaryHeadline: String {
        if photos.isEmpty {
            return "We have no photos of you on our servers."
        }
        let bytes = ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
        return "\(photos.count) photo\(photos.count == 1 ? "" : "s") · \(bytes)"
    }

    private var summarySub: String {
        if photos.isEmpty {
            return "Body-scan photos are processed in memory and discarded. Nothing's been stored for you yet."
        }
        return "Across both server buckets. Auto-deleted by retention policy (30 days for projections, 7 days for battles), or remove them now below."
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ON OUR SERVERS")

            bucketRow(
                title: "Future You source photos",
                subtitle: "Used to generate your AI projection. Deleted after 30 days.",
                count: goalProjectionPhotos.count,
                icon: "sparkles",
                tint: .purple
            )

            bucketRow(
                title: "1v1 battle photos",
                subtitle: "Submitted for physique battles. Deleted 7 days after the battle ends.",
                count: challengePhotos.count,
                icon: "bolt.fill",
                tint: .orange
            )

            bucketRow(
                title: "Body scan photos used purely for scoring",
                subtitle: "Not stored — processed in memory and discarded after analysis.",
                count: nil,
                icon: "camera.viewfinder",
                tint: .blue
            )
        }
    }

    private var localSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ON THIS IPHONE ONLY")

            bucketRow(
                title: "Profile avatar",
                subtitle: "Encrypted on-device. Never uploaded.",
                count: appState.profile.customPhotoData != nil ? 1 : 0,
                icon: "person.crop.circle.fill",
                tint: .gray
            )
            bucketRow(
                title: "Default 1v1 photo",
                subtitle: "Your saved battle photo. Encrypted on-device. Never uploaded.",
                count: appState.hasBattlePhoto ? 1 : 0,
                icon: "figure.mixed.cardio",
                tint: .gray
            )
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                showConfirmDeleteAll = true
            } label: {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView().controlSize(.small)
                            .tint(Color(.systemBackground))
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(isDeleting ? "Deleting..." : "Delete all server-stored photos")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(photos.isEmpty ? Color.red.opacity(0.40) : Color.red)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(photos.isEmpty || isDeleting || isLoading)

            if let count = lastDeletedCount {
                Label("\(count) photo\(count == 1 ? "" : "s") deleted", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }

            Button {
                refreshTrigger += 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Refresh count")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)
            Text("This page satisfies your right of access (GDPR Art. 15) and right to erasure (Art. 17) as an immediate self-service surface. For broader requests — full data export, account deletion, complaints — email **team@fitai.health**.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Link(destination: LegalLinks.privacy) {
                    Label("Read full privacy policy", systemImage: "doc.text")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .tracking(2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func bucketRow(
        title: String,
        subtitle: String,
        count: Int?,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let count {
                Text("\(count)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(count == 0 ? .tertiary : .primary)
            } else {
                Text("0")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let userId else {
            photos = []
            return
        }
        photos = await PhotoUploadService.shared.listUserPhotos(userId: userId)
    }

    private func deleteAll() async {
        guard let userId else { return }
        isDeleting = true
        let removed = await PhotoUploadService.shared.deleteAllUserPhotos(userId: userId)
        isDeleting = false
        lastDeletedCount = removed
        // Re-load so the counts update.
        photos = []
        refreshTrigger += 1
    }
}
