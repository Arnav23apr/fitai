import SwiftUI

struct HeightWeightView: View {
    @Environment(AppState.self) private var appState
    var onContinue: () -> Void
    @State private var usesMetric: Bool = false
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 9
    @State private var heightCm: Int = 175
    @State private var weightLbs: Int = 165
    @State private var weightKg: Int = 75
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Your Body")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
                Text("Measurements")
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)

            Picker("Unit", selection: $usesMetric) {
                Text("Imperial").tag(false)
                Text("Metric").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .opacity(appeared ? 1 : 0)

            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("HEIGHT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1)

                    if usesMetric {
                        Picker("Height", selection: $heightCm) {
                            ForEach(120...220, id: \.self) { cm in
                                Text("\(cm) cm")
                                    .foregroundStyle(.white)
                                    .tag(cm)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 180)
                        .clipShape(.rect(cornerRadius: 16))
                    } else {
                        HStack(spacing: 4) {
                            Picker("Feet", selection: $heightFeet) {
                                ForEach(4...7, id: \.self) { ft in
                                    Text("\(ft) ft")
                                        .foregroundStyle(.white)
                                        .tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 180)

                            Picker("Inches", selection: $heightInches) {
                                ForEach(0...11, id: \.self) { inch in
                                    Text("\(inch) in")
                                        .foregroundStyle(.white)
                                        .tag(inch)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 180)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    Text("WEIGHT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1)

                    if usesMetric {
                        Picker("Weight", selection: $weightKg) {
                            ForEach(30...200, id: \.self) { kg in
                                Text("\(kg) kg")
                                    .foregroundStyle(.white)
                                    .tag(kg)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 180)
                        .clipShape(.rect(cornerRadius: 16))
                    } else {
                        Picker("Weight", selection: $weightLbs) {
                            ForEach(66...440, id: \.self) { lbs in
                                Text("\(lbs) lbs")
                                    .foregroundStyle(.white)
                                    .tag(lbs)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 180)
                        .clipShape(.rect(cornerRadius: 16))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .opacity(appeared ? 1 : 0)

            Spacer()

            Button(action: {
                if usesMetric {
                    appState.profile.heightCm = Double(heightCm)
                    appState.profile.weightKg = Double(weightKg)
                } else {
                    appState.profile.heightCm = Double(heightFeet) * 30.48 + Double(heightInches) * 2.54
                    appState.profile.weightKg = Double(weightLbs) * 0.453592
                }
                appState.profile.usesMetric = usesMetric
                onContinue()
            }) {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}
