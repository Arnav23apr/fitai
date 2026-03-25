import SwiftUI
import HealthKit

struct AppleHealthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @State private var isRequesting: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isConnected: Bool = false

    private let healthStore = HKHealthStore()
    private var isDark: Bool { colorScheme == .dark }

    private let dataTypes: [(icon: String, color: Color, title: String, detail: String)] = [
        ("figure.run", .orange, "Workouts", "Read and write workout sessions"),
        ("scalemass.fill", .blue, "Body Weight", "Read and write weight measurements"),
        ("heart.fill", .pink, "Heart Rate", "Read heart rate during workouts"),
        ("bolt.heart.fill", .red, "Active Energy", "Read calories burned"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        iconHeader
                        descriptionSection
                        dataAccessSection
                        privacyNote
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 32)
                }

                Spacer(minLength: 0)
                actionButtons
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Unable to Connect", isPresented: $showError) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var iconHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .pink.opacity(0.4), radius: 16, y: 6)
                Image(systemName: "heart.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("Connect Apple Health")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Allow FitAI to read and write your\nhealth and fitness data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var descriptionSection: some View {
        Text("FitAI uses Apple Health to automatically log your workouts, track body weight trends, and give you a complete picture of your fitness progress, all stored privately on your device.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private var dataAccessSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DATA FitAI WILL ACCESS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(dataTypes.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 14) {
                        Image(systemName: item.icon)
                            .font(.system(size: 17))
                            .foregroundStyle(item.color)
                            .frame(width: 36, height: 36)
                            .background(item.color.opacity(0.12))
                            .clipShape(.rect(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(isConnected ? .green : Color(.systemGray4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < dataTypes.count - 1 {
                        Divider()
                            .padding(.leading, 66)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 14))
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
            Text("Your health data is stored securely on your device and never shared with third parties.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.green.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: connectHealth) {
                Group {
                    if isRequesting {
                        ProgressView()
                            .tint(isDark ? .black : .white)
                    } else if isConnected {
                        Label("Connected", systemImage: "checkmark")
                            .font(.headline)
                            .foregroundStyle(isDark ? .black : .white)
                    } else {
                        Text("Connect Apple Health")
                            .font(.headline)
                            .foregroundStyle(isDark ? .black : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isDark ? Color.white : Color.black)
                .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(isRequesting || isConnected)

            Button("Not Now") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }

    private func connectHealth() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Apple Health is not available on this device."
            showError = true
            return
        }

        isRequesting = true

        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        ]
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        ]

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            Task { @MainActor in
                isRequesting = false
                if let error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else {
                    isConnected = success
                    UserDefaults.standard.set(success, forKey: "healthConnected")
                    if success {
                        await syncBodyWeight()
                        try? await Task.sleep(for: .seconds(0.8))
                        dismiss()
                    }
                }
            }
        }
    }

    private func syncBodyWeight() async {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        let weightKg = appState.profile.weightKg
        guard weightKg > 0 else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: Date(), end: Date())
        try? await healthStore.save(sample)
    }
}
