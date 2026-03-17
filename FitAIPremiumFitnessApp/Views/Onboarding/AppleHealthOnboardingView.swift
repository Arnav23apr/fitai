import SwiftUI
import HealthKit

struct AppleHealthOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    var onContinue: () -> Void

    @State private var appeared: Bool = false
    @State private var isRequesting: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private var isDark: Bool { colorScheme == .dark }
    private let healthStore = HKHealthStore()

    private let dataTypes: [(icon: String, color: Color, title: String)] = [
        ("figure.run",        .orange, "Workouts"),
        ("scalemass.fill",    .blue,   "Body Weight"),
        ("heart.fill",        .pink,   "Heart Rate"),
        ("bolt.heart.fill",   .red,    "Active Energy"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                iconBlock
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                dataList
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }

            Spacer()

            buttons
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { appeared = true }
        }
        .alert("Unable to Connect", isPresented: $showError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Skip", role: .cancel) { onContinue() }
        } message: {
            Text(errorMessage)
        }
    }

    private var iconBlock: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.red.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: .pink.opacity(0.45), radius: 20, y: 8)
                Image(systemName: "heart.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Connect Apple Health")
                    .font(.system(.title2, design: .default, weight: .bold))
                    .foregroundStyle(.primary)
                Text("FitAI syncs your workouts and body metrics\nwith Apple Health — all stored privately on device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 32)
    }

    private var dataList: some View {
        VStack(spacing: 0) {
            ForEach(Array(dataTypes.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(item.color)
                        .frame(width: 38, height: 38)
                        .background(item.color.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 9))

                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                if index < dataTypes.count - 1 {
                    Divider().padding(.leading, 68)
                }
            }
        }
        .background(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button(action: connectHealth) {
                Group {
                    if isRequesting {
                        ProgressView()
                            .tint(isDark ? .black : .white)
                    } else {
                        Text("Connect Apple Health")
                            .font(.headline)
                            .foregroundStyle(isDark ? .black : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isDark ? Color.white : Color.black)
                .clipShape(.rect(cornerRadius: 16))
            }
            .disabled(isRequesting)

            Button("Skip for Now") {
                onContinue()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private func connectHealth() {
        guard HKHealthStore.isHealthDataAvailable() else {
            onContinue()
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
                    UserDefaults.standard.set(success, forKey: "healthConnected")
                    if success {
                        await syncBodyWeight()
                    }
                    onContinue()
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
