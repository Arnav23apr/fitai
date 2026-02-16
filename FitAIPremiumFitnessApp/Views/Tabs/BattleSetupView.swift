import SwiftUI
import PhotosUI

struct BattleSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = BattleViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection

                    HStack(spacing: 16) {
                        photoCard(
                            title: "You",
                            image: viewModel.playerPhoto,
                            pickerItem: $viewModel.playerPickerItem
                        )

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
            .background(Color.black)
            .navigationTitle("1v1 Battle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .onChange(of: viewModel.playerPickerItem) { _, _ in
                Task { await viewModel.loadPlayerPhoto() }
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
                .foregroundStyle(.white)

            Text("Upload both physique photos and let AI decide who gets mogged")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
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
                            .foregroundStyle(.white.opacity(0.3))
                        Text("Add Photo")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 140, height: 190)
                    .background(Color.white.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                    )
                }
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
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
                .foregroundStyle(.white.opacity(0.5))

            TextField("", text: $viewModel.opponentName, prompt: Text("Enter name").foregroundStyle(.white.opacity(0.2)))
                .font(.body)
                .foregroundStyle(.white)
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
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
                    : LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.06)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(!viewModel.canStartBattle || viewModel.isAnalyzing)
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.showResult)
    }
}
