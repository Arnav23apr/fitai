import SwiftUI
import AVFoundation

struct CameraProxyView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            #if targetEnvironment(simulator)
            CameraUnavailablePlaceholder(onDismiss: { dismiss() })
            #else
            if AVCaptureDevice.default(for: .video) != nil {
                CameraPicker(onImageCaptured: onImageCaptured)
            } else {
                CameraUnavailablePlaceholder(onDismiss: { dismiss() })
            }
            #endif
        }
    }
}

struct CameraUnavailablePlaceholder: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera Preview")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Install this app on your device\nvia the Rork App to use the camera.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Close") {
                onDismiss()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray3))
            .clipShape(.rect(cornerRadius: 14))
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
