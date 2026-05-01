import SwiftUI
import PhotosUI

struct BattleSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel = BattleViewModel()
    @State private var showDefaultSaved: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection

                    HStack(spacing: 16) {
                        playerPhotoCard

                        vsLabel

                        photoCard(
                            title: "Opponent",
                            image: viewModel.opponentPhoto,
                            pickerItem: $viewModel.opponentPickerItem
                        )
                    }

                    nameField

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    battleButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle("1v1 Battle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if viewModel.isAnalyzing {
                    AnalyzingOverlayView(mode: .battle)
                        .transition(.opacity)
                        .ignoresSafeArea()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isAnalyzing)
            .onAppear {
                viewModel.prefillPlayerPhoto(
                    battlePhotoData: appState.loadBattlePhoto(),
                    profileData: appState.profile.customPhotoData,
                    name: appState.profile.name
                )
            }
            .onChange(of: viewModel.playerPickerItem) { _, _ in
                Task {
                    await viewModel.loadPlayerPhoto()
                    viewModel.playerPhotoIsDefault = false
                }
            }
            .onChange(of: viewModel.opponentPickerItem) { _, _ in
                Task { await viewModel.loadOpponentPhoto() }
            }
            .fullScreenCover(isPresented: $viewModel.showResult) {
                if let battle = viewModel.battleResult {
                    BattleResultView(battle: battle) {
                        viewModel.reset()
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.red.opacity(0.3), .red.opacity(0.05), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "figure.mixed.cardio")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
            }

            Text("Physique Battle")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text("Upload both physique photos and let AI decide who gets mogged")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var playerPhotoCard: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $viewModel.playerPickerItem, matching: .images) {
                if let img = viewModel.playerPhoto {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 190)
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(alignment: .topTrailing) {
                            if viewModel.playerPhotoIsDefault {
                                Text("Default")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.85))
                                    .clipShape(Capsule())
                                    .padding(6)
                            }
                        }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Add Photo")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    )
                }
            }

            Text("You")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if viewModel.playerPhoto != nil {
                Button {
                    if viewModel.playerPhotoIsDefault {
                        appState.clearBattlePhoto()
                        viewModel.playerPhotoIsDefault = false
                    } else if let photo = viewModel.playerPhoto,
                              let data = photo.jpegData(compressionQuality: 0.85) {
                        appState.saveBattlePhoto(data)
                        viewModel.playerPhotoIsDefault = true
                        showDefaultSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showDefaultSaved = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.playerPhotoIsDefault ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text(viewModel.playerPhotoIsDefault ? "Remove Default" : "Set as Default")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.playerPhotoIsDefault ? .red : .secondary)
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.25), value: viewModel.playerPhotoIsDefault)
    }

    private func photoCard(title: String, image: UIImage?, pickerItem: Binding<PhotosPickerItem?>) -> some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: pickerItem, matching: .images) {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 190)
                        .clipShape(.rect(cornerRadius: 16))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Add Photo")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    )
                }
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var vsLabel: some View {
        Text("VS")
            .font(.system(.title3, design: .rounded, weight: .black))
            .foregroundStyle(.red)
            .padding(.top, 20)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Opponent's Name")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("", text: $viewModel.opponentName, prompt: Text("Enter name").foregroundStyle(.tertiary))
                .font(.body)
                .foregroundStyle(.primary)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private var battleButton: some View {
        Button {
            Task { await viewModel.startBattle() }
        } label: {
            Group {
                if viewModel.isAnalyzing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text(viewModel.analyzeProgress)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Start Battle")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                viewModel.canStartBattle && !viewModel.isAnalyzing
                    ? LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(!viewModel.canStartBattle || viewModel.isAnalyzing)
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.showResult)
    }
}
