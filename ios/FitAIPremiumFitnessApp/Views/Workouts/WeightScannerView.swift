import SwiftUI
import AVFoundation
import UIKit

/// Camera capture for photo-based set logging. Uses the simpler
/// `UIImagePickerController` source (camera) wrapped in
/// `UIViewControllerRepresentable` so the user gets the standard iOS shutter
/// UX without us reimplementing AVCaptureSession. The captured image is
/// handed back via `onCapture`.
///
/// We deliberately don't use `DataScannerViewController` here because its
/// live-OCR overlay is best for tap-to-pick-text flows (like a barcode
/// scanner). For our case the user is framing a *scene* (loaded barbell,
/// machine, weight stack) — a single shutter press is more natural.
struct WeightScannerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void
        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            } else {
                onCancel()
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
