import SwiftUI

/// Dedicated "how to perform" sheet — looping demo + instructions + tips.
/// Presented from ExerciseDetailSheet so the detail screen can stay focused
/// on tracking data (history, PRs, overload).
struct ExerciseHowToSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    private var demo: ExerciseDemoInfo { exercise.demoInfo }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if demo.hasMedia {
                        LoopingVideoView(
                            videoURL: demo.videoURL,
                            thumbnailURL: demo.thumbnailURL,
                            frames: demo.frames
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    }

                    if !demo.instructions.isEmpty {
                        instructionsCard
                    }

                    if !demo.tips.isEmpty {
                        tipsCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemBackground))
            .navigationTitle("How to perform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                Text("Steps")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(demo.instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.blue)
                            .clipShape(Circle())

                        Text(instruction)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.blue.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.blue.opacity(0.08), lineWidth: 1)
        )
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text("Pro Tips")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(demo.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                            .padding(.top, 1)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(.primary.opacity(0.85))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.yellow.opacity(0.04))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.yellow.opacity(0.08), lineWidth: 1)
        )
    }
}
