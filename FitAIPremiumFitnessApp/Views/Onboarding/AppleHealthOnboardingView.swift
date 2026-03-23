import SwiftUI
import HealthKit

struct AppleHealthOnboardingView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void

    @State private var appeared:    Bool   = false
    @State private var isRequesting: Bool  = false
    @State private var showError:   Bool   = false
    @State private var errorMessage: String = ""
    @State private var pulseScale:  CGFloat = 1.0

    private let healthStore = HKHealthStore()

    private let dataTypes: [(icon: String, label: String)] = [
        ("figure.run",      "Workouts"),
        ("scalemass.fill",  "Body Weight"),
        ("heart.fill",      "Heart Rate"),
        ("bolt.heart.fill", "Active Energy"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Hero ──
                VStack(spacing: 28) {
                    heartIcon
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.8)

                    VStack(spacing: 10) {
                        Text("Connect Apple Health")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)

                        Text("FitAI syncs your workouts and body\nmetrics — all stored privately on device.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.50))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 40)

                // ── Permission list ──
                VStack(spacing: 0) {
                    ForEach(Array(dataTypes.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

                            Text(item.label)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.40))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)

                        if index < dataTypes.count - 1 {
                            Rectangle()
                                .fill(.white.opacity(0.07))
                                .frame(height: 1)
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()

                // ── Buttons ──
                VStack(spacing: 12) {
                    Button(action: connectHealth) {
                        ZStack {
                            if isRequesting {
                                ProgressView().tint(.black)
                            } else {
                                Text("Connect Apple Health")
                                    .font(.system(.headline, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(.rect(cornerRadius: 28))
                    }
                    .disabled(isRequesting)

                    Button("Skip for Now") { onContinue() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.40))
                        .frame(height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.18
            }
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

    // MARK: - Heart icon (native HealthKit style)

    private var heartIcon: some View {
        ZStack {
            // Pulse ring
            Circle()
                .fill(.red.opacity(0.15))
                .frame(width: 104, height: 104)
                .scaleEffect(pulseScale)

            Circle()
                .fill(.red.opacity(0.08))
                .frame(width: 118, height: 118)
                .scaleEffect(pulseScale * 1.05)

            // Icon background — matches native Health app shape
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.22, blue: 0.27),
                                 Color(red: 0.85, green: 0.10, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: .red.opacity(0.50), radius: 18, y: 6)

            Image(systemName: "heart.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    // MARK: - HealthKit request

    private func connectHealth() {
        guard HKHealthStore.isHealthDataAvailable() else { onContinue(); return }
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
                    if success { await syncBodyWeight() }
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
        let sample   = HKQuantitySample(type: bodyMassType, quantity: quantity, start: Date(), end: Date())
        try? await healthStore.save(sample)
    }
}
