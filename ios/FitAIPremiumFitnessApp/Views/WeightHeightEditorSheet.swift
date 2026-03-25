import SwiftUI

struct WeightHeightEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @State private var usesMetric: Bool = false
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 9
    @State private var heightCm: Int = 175
    @State private var weightLbs: Int = 165
    @State private var weightKg: Int = 75

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                        .frame(width: 56, height: 56)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())

                    Text("Update Measurements")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Keep your weight updated for accurate bodyweight tracking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 8)

                Picker("Unit", selection: $usesMetric) {
                    Text("Imperial").tag(false)
                    Text("Metric").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 20)

                HStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("HEIGHT")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        if usesMetric {
                            Picker("Height", selection: $heightCm) {
                                ForEach(120...220, id: \.self) { cm in
                                    Text("\(cm) cm")
                                        .foregroundStyle(.primary)
                                        .tag(cm)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 160)
                            .clipShape(.rect(cornerRadius: 16))
                        } else {
                            HStack(spacing: 4) {
                                Picker("Feet", selection: $heightFeet) {
                                    ForEach(4...7, id: \.self) { ft in
                                        Text("\(ft) ft")
                                            .foregroundStyle(.primary)
                                            .tag(ft)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 72, height: 160)

                                Picker("Inches", selection: $heightInches) {
                                    ForEach(0...11, id: \.self) { inch in
                                        Text("\(inch) in")
                                            .foregroundStyle(.primary)
                                            .tag(inch)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 72, height: 160)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 8) {
                        Text("WEIGHT")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(1)

                        if usesMetric {
                            Picker("Weight", selection: $weightKg) {
                                ForEach(30...200, id: \.self) { kg in
                                    Text("\(kg) kg")
                                        .foregroundStyle(.primary)
                                        .tag(kg)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 160)
                            .clipShape(.rect(cornerRadius: 16))
                        } else {
                            Picker("Weight", selection: $weightLbs) {
                                ForEach(66...440, id: \.self) { lbs in
                                    Text("\(lbs) lbs")
                                        .foregroundStyle(.primary)
                                        .tag(lbs)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 160)
                            .clipShape(.rect(cornerRadius: 16))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                Button {
                    save()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(isDark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isDark ? Color.white : Color.black)
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            usesMetric = appState.profile.usesMetric
            let cm = appState.profile.heightCm
            let kg = appState.profile.weightKg
            heightCm = Int(cm)
            heightFeet = Int(cm / 30.48)
            heightInches = Int((cm / 2.54).truncatingRemainder(dividingBy: 12))
            weightKg = Int(kg)
            weightLbs = Int(kg * 2.205)
        }
    }

    private func save() {
        if usesMetric {
            appState.profile.heightCm = Double(heightCm)
            appState.profile.weightKg = Double(weightKg)
        } else {
            appState.profile.heightCm = Double(heightFeet) * 30.48 + Double(heightInches) * 2.54
            appState.profile.weightKg = Double(weightLbs) * 0.453592
        }
        appState.profile.usesMetric = usesMetric
        appState.saveProfile()
        dismiss()
    }
}
