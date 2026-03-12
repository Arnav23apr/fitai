import SwiftUI
import HealthKit

struct AppleHealthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @State private var workoutsEnabled: Bool = UserDefaults.standard.bool(forKey: "healthWorkoutsEnabled")
    @State private var bodyWeightEnabled: Bool = UserDefaults.standard.bool(forKey: "healthBodyWeightEnabled")
    @State private var permissionStatus: HKAuthorizationStatus = .notDetermined
    @State private var isRequesting: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let healthStore = HKHealthStore()
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard
                    connectionCards
                    benefitsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.medium)
                }
            }
            .alert("Permission Error", isPresented: $showError) {
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

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.pink)
                    .frame(width: 56, height: 56)
                Image(systemName: "heart.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Health")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Sync your fitness data with Apple Health for a complete health picture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.pink.opacity(0.08), Color.red.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.pink.opacity(0.15), lineWidth: 1)
        )
    }

    private var connectionCards: some View {
        VStack(spacing: 12) {
            healthDataCard(
                icon: "figure.run",
                iconColor: .orange,
                title: "Workouts",
                subtitle: "Read & write workout sessions",
                isEnabled: $workoutsEnabled
            ) {
                requestPermissions()
            }

            healthDataCard(
                icon: "scalemass.fill",
                iconColor: .blue,
                title: "Body Weight",
                subtitle: "Read & write weight measurements",
                isEnabled: $bodyWeightEnabled
            ) {
                requestPermissions()
            }
        }
    }

    private func healthDataCard(icon: String, iconColor: Color, title: String, subtitle: String, isEnabled: Binding<Bool>, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRequesting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle("", isOn: isEnabled)
                    .tint(.pink)
                    .labelsHidden()
                    .onChange(of: isEnabled.wrappedValue) { _, newValue in
                        if newValue {
                            onToggle()
                        }
                        UserDefaults.standard.set(newValue, forKey: title == "Workouts" ? "healthWorkoutsEnabled" : "healthBodyWeightEnabled")
                    }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benefits")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                benefitRow(icon: "heart.text.square.fill", color: .pink, text: "See all your health data in one place")
                benefitRow(icon: "chart.xyaxis.line", color: .blue, text: "Track weight trends alongside workouts")
                benefitRow(icon: "figure.strengthtraining.traditional", color: .orange, text: "Workouts automatically added to Health")
                benefitRow(icon: "lock.shield.fill", color: .green, text: "Your data stays private on your device")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func benefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Apple Health is not available on this device."
            showError = true
            return
        }

        isRequesting = true

        var readTypes: Set<HKObjectType> = []
        var writeTypes: Set<HKSampleType> = []

        if workoutsEnabled {
            readTypes.insert(HKObjectType.workoutType())
            writeTypes.insert(HKObjectType.workoutType())
        }

        if bodyWeightEnabled {
            if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
                readTypes.insert(bodyMassType)
                writeTypes.insert(bodyMassType)
            }
        }

        guard !readTypes.isEmpty else {
            isRequesting = false
            return
        }

        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            Task { @MainActor in
                isRequesting = false
                if let error {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                if success && bodyWeightEnabled {
                    await syncBodyWeight()
                }
            }
        }
    }

    private func syncBodyWeight() async {
        guard bodyWeightEnabled,
              let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        let weightKg = appState.profile.weightKg
        guard weightKg > 0 else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: Date(), end: Date())
        try? await healthStore.save(sample)
    }
}
