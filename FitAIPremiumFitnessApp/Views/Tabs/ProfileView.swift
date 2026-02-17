import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showEditProfile: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showLanguagePicker: Bool = false
    @State private var showHealthAlert: Bool = false
    @State private var notificationsEnabled: Bool = true

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    userCard
                    statsCard
                    if appState.profile.spinDiscount != nil && !appState.profile.isPremium {
                        limitedOfferCard
                    }
                    scanHistorySection
                    settingsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("profile", lang))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.profile.isPremium {
                        Text("PRO")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerSheet()
            }
            .alert(L.t("comingSoon", lang), isPresented: $showHealthAlert) {
                Button(L.t("ok", lang), role: .cancel) {}
            } message: {
                Text(L.t("comingSoonMessage", lang))
            }
        }
    }

    private var userCard: some View {
        HStack(spacing: 16) {
            Group {
                if let photoData = appState.profile.customPhotoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                } else {
                    Image(systemName: appState.profile.avatarSystemName)
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                        .frame(width: 64, height: 64)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.profile.name.isEmpty ? "Athlete" : appState.profile.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                if !appState.profile.goals.isEmpty {
                    Text(appState.profile.goals.prefix(2).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if !appState.profile.bio.isEmpty {
                    Text(appState.profile.bio)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button(action: { showEditProfile = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            profileStat(value: "\(appState.profile.totalScans)", label: "Scans")
            profileDivider
            profileStat(value: "\(appState.profile.totalWorkouts)", label: "Workouts")
            profileDivider
            profileStat(value: "\(appState.profile.currentStreak)", label: "Streak")
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var profileDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 36)
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var limitedOfferCard: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Limited Offer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let discount = appState.profile.spinDiscount {
                        Text("\(discount)% off Pro — Claim now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.yellow.opacity(0.08), Color.orange.opacity(0.04)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var scanHistorySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L.t("scanHistory", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            if appState.profile.totalScans == 0 {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(L.t("noScansYet", lang))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
            } else if let score = appState.profile.latestScore, let date = appState.profile.lastScanDate {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.1f", score))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L.t("settings", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            VStack(spacing: 0) {
                settingsToggle(title: L.t("notifications", lang), icon: "bell.fill", isOn: $notificationsEnabled)
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("appleHealth", lang), icon: "heart.fill", iconColor: .pink) {
                    showHealthAlert = true
                }
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("restorePurchases", lang), icon: "arrow.clockwise") {
                    appState.profile.isPremium = true
                    appState.saveProfile()
                }
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("language", lang), icon: "globe", trailing: appState.profile.selectedLanguage) {
                    showLanguagePicker = true
                }
                Divider().padding(.leading, 52)
                settingsRow(title: L.t("termsPrivacy", lang), icon: "doc.text") {}
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))

            Button(action: {
                appState.logout()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text(L.t("logOut", lang))
                        .font(.subheadline)
                }
                .foregroundStyle(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 16))
            }
        }
    }

    private func settingsToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(.green)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsRow(title: String, icon: String, iconColor: Color = .secondary, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var customPhotoData: Data? = nil

    private let avatarOptions = [
        "person.crop.circle.fill",
        "figure.run",
        "figure.strengthtraining.traditional",
        "figure.boxing",
        "figure.martial.arts",
        "dumbbell.fill"
    ]

    @State private var selectedAvatar: String = "person.crop.circle.fill"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            if let photoData = customPhotoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 88, height: 88)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: selectedAvatar)
                                    .font(.system(size: 56))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 88, height: 88)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(Circle())
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(.systemBackground))
                                    .frame(width: 28, height: 28)
                                    .background(Color(.label))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                            }
                            .offset(x: 2, y: 2)
                        }

                        if customPhotoData != nil {
                            Button("Remove Photo") {
                                withAnimation {
                                    customPhotoData = nil
                                    selectedPhotoItem = nil
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(avatarOptions, id: \.self) { avatar in
                                    Button(action: {
                                        selectedAvatar = avatar
                                        customPhotoData = nil
                                        selectedPhotoItem = nil
                                    }) {
                                        Image(systemName: avatar)
                                            .font(.system(size: 22))
                                            .foregroundStyle(selectedAvatar == avatar && customPhotoData == nil ? Color(.systemBackground) : .secondary)
                                            .frame(width: 44, height: 44)
                                            .background(selectedAvatar == avatar && customPhotoData == nil ? Color(.label) : Color(.secondarySystemGroupedBackground))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .contentMargins(.horizontal, 0)
                    }

                    VStack(spacing: 14) {
                        TextField("Name", text: $name)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(.rect(cornerRadius: 12))

                        TextField("Short bio (optional)", text: $bio)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(.rect(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.profile.name = name
                        appState.profile.bio = bio
                        appState.profile.avatarSystemName = selectedAvatar
                        appState.profile.customPhotoData = customPhotoData
                        appState.saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        customPhotoData = data
                    }
                }
            }
        }
        .onAppear {
            name = appState.profile.name
            bio = appState.profile.bio
            selectedAvatar = appState.profile.avatarSystemName
            customPhotoData = appState.profile.customPhotoData
        }
    }
}

struct LanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedLanguage: String = "English"

    private let languages: [(name: String, flag: String, native: String)] = [
        ("English", "🇺🇸", "English"),
        ("Arabic", "🇸🇦", "العربية"),
        ("Chinese", "🇨🇳", "中文"),
        ("Dutch", "🇳🇱", "Nederlands"),
        ("French", "🇫🇷", "Français"),
        ("German", "🇩🇪", "Deutsch"),
        ("Hebrew", "🇮🇱", "עברית"),
        ("Hindi", "🇮🇳", "हिन्दी"),
        ("Italian", "🇮🇹", "Italiano"),
        ("Japanese", "🇯🇵", "日本語"),
        ("Korean", "🇰🇷", "한국어"),
        ("Polish", "🇵🇱", "Polski"),
        ("Portuguese", "🇧🇷", "Português"),
        ("Romanian", "🇷🇴", "Română"),
        ("Russian", "🇷🇺", "Русский"),
        ("Spanish", "🇪🇸", "Español"),
        ("Swedish", "🇸🇪", "Svenska"),
        ("Turkish", "🇹🇷", "Türkçe"),
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(languages, id: \.name) { language in
                    Button {
                        selectedLanguage = language.name
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.flag)
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.native)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                if language.native != language.name {
                                    Text(language.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selectedLanguage == language.name {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t("language", appState.profile.selectedLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("cancel", appState.profile.selectedLanguage)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("save", appState.profile.selectedLanguage)) {
                        appState.profile.selectedLanguage = selectedLanguage
                        appState.saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedLanguage = appState.profile.selectedLanguage
        }
    }
}
