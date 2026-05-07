import SwiftUI
import Charts

/// Body measurements log + weight progression chart — Hevy/Strong "Measurements"
/// tab. List of dated entries on top, chart of weight over time below, "+ Add"
/// button to create a new entry.
struct BodyMeasurementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var service = BodyMeasurementService.shared
    @State private var showEditor: Bool = false
    @State private var editingEntry: BodyMeasurement? = nil

    private var lang: String { appState.profile.selectedLanguage }
    private var usesMetric: Bool { appState.profile.usesMetric }

    var body: some View {
        NavigationStack {
            Group {
                if service.measurements.isEmpty {
                    emptyState
                } else {
                    contentList
                }
            }
            .navigationTitle("Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        editingEntry = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                BodyMeasurementEditor(initial: editingEntry)
            }
            .sheet(item: $editingEntry) { entry in
                BodyMeasurementEditor(initial: entry)
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "ruler.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No measurements yet")
                .font(.headline)
            Text("Track waist, arms, weight, and more so you can see real progress between scans.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button {
                editingEntry = nil
                showEditor = true
            } label: {
                Text("Add first entry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.primary)
                    .clipShape(.capsule)
            }
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    private var contentList: some View {
        List {
            if !service.weightSeries.isEmpty {
                Section("Weight trend") {
                    weightChart
                        .frame(height: 180)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }

            Section("History") {
                ForEach(service.measurements) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        entryRow(entry)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { idx in
                    let ids = idx.map { service.measurements[$0].id }
                    ids.forEach { service.remove(id: $0) }
                }
            }
        }
    }

    private var weightChart: some View {
        Chart {
            ForEach(service.weightSeries, id: \.0) { (date, kg) in
                let displayed = usesMetric ? kg : kg * 2.20462
                LineMark(
                    x: .value("Date", date),
                    y: .value("Weight", displayed)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.primary.opacity(0.85))
                PointMark(
                    x: .value("Date", date),
                    y: .value("Weight", displayed)
                )
                .foregroundStyle(Color.primary)
                .symbolSize(36)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let kg = value.as(Double.self) {
                        Text(usesMetric ? "\(Int(kg))kg" : "\(Int(kg))lb")
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.date, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if let kg = entry.weightKg {
                    Text(formatWeight(kg))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            // Compact summary chips for whichever measurements were
            // recorded — skips nil fields silently.
            FlowLayout(spacing: 6) {
                ForEach(summaryChips(for: entry), id: \.self) { chip in
                    Text(chip)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(.capsule)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func summaryChips(for entry: BodyMeasurement) -> [String] {
        var chips: [String] = []
        if let v = entry.chestCm { chips.append("Chest \(formatLength(v))") }
        if let v = entry.waistCm { chips.append("Waist \(formatLength(v))") }
        if let v = entry.hipsCm { chips.append("Hips \(formatLength(v))") }
        if let v = entry.shouldersCm { chips.append("Shoulders \(formatLength(v))") }
        if let v = entry.leftArmCm { chips.append("L arm \(formatLength(v))") }
        if let v = entry.rightArmCm { chips.append("R arm \(formatLength(v))") }
        if let v = entry.leftThighCm { chips.append("L thigh \(formatLength(v))") }
        if let v = entry.rightThighCm { chips.append("R thigh \(formatLength(v))") }
        if let v = entry.neckCm { chips.append("Neck \(formatLength(v))") }
        return chips
    }

    private func formatWeight(_ kg: Double) -> String {
        usesMetric ? String(format: "%.1f kg", kg) : String(format: "%.1f lb", kg * 2.20462)
    }

    private func formatLength(_ cm: Double) -> String {
        usesMetric ? String(format: "%.0f cm", cm) : String(format: "%.1f in", cm / 2.54)
    }
}

// MARK: - Editor

private struct BodyMeasurementEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var service = BodyMeasurementService.shared

    let initial: BodyMeasurement?

    @State private var date: Date
    @State private var weight: String
    @State private var chest: String
    @State private var waist: String
    @State private var hips: String
    @State private var shoulders: String
    @State private var leftArm: String
    @State private var rightArm: String
    @State private var leftThigh: String
    @State private var rightThigh: String
    @State private var leftCalf: String
    @State private var rightCalf: String
    @State private var neck: String
    @State private var notes: String

    init(initial: BodyMeasurement?) {
        self.initial = initial
        // Initialise from existing values converted into the user's preferred
        // unit so the form shows what they last entered, not the cm/kg backing.
        let usesMetric = AppState.loadUsesMetricSnapshot()
        let entry = initial ?? BodyMeasurement()
        _date = State(initialValue: entry.date)
        _weight = State(initialValue: entry.weightKg.map {
            usesMetric ? String(format: "%.1f", $0) : String(format: "%.1f", $0 * 2.20462)
        } ?? "")
        _chest = State(initialValue: entry.chestCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _waist = State(initialValue: entry.waistCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _hips = State(initialValue: entry.hipsCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _shoulders = State(initialValue: entry.shouldersCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _leftArm = State(initialValue: entry.leftArmCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _rightArm = State(initialValue: entry.rightArmCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _leftThigh = State(initialValue: entry.leftThighCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _rightThigh = State(initialValue: entry.rightThighCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _leftCalf = State(initialValue: entry.leftCalfCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _rightCalf = State(initialValue: entry.rightCalfCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _neck = State(initialValue: entry.neckCm.map { Self.fmtLen($0, metric: usesMetric) } ?? "")
        _notes = State(initialValue: entry.notes)
    }

    private static func fmtLen(_ cm: Double, metric: Bool) -> String {
        metric ? String(format: "%.1f", cm) : String(format: "%.2f", cm / 2.54)
    }

    private var usesMetric: Bool { appState.profile.usesMetric }
    private var weightUnit: String { usesMetric ? "kg" : "lb" }
    private var lengthUnit: String { usesMetric ? "cm" : "in" }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Weight") {
                    measureField(label: "Weight", text: $weight, unit: weightUnit)
                }

                Section("Upper body") {
                    measureField(label: "Chest", text: $chest, unit: lengthUnit)
                    measureField(label: "Shoulders", text: $shoulders, unit: lengthUnit)
                    measureField(label: "Neck", text: $neck, unit: lengthUnit)
                    measureField(label: "Left arm", text: $leftArm, unit: lengthUnit)
                    measureField(label: "Right arm", text: $rightArm, unit: lengthUnit)
                }

                Section("Core") {
                    measureField(label: "Waist", text: $waist, unit: lengthUnit)
                    measureField(label: "Hips", text: $hips, unit: lengthUnit)
                }

                Section("Lower body") {
                    measureField(label: "Left thigh", text: $leftThigh, unit: lengthUnit)
                    measureField(label: "Right thigh", text: $rightThigh, unit: lengthUnit)
                    measureField(label: "Left calf", text: $leftCalf, unit: lengthUnit)
                    measureField(label: "Right calf", text: $rightCalf, unit: lengthUnit)
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if initial != nil {
                    Section {
                        Button(role: .destructive) {
                            if let id = initial?.id {
                                service.remove(id: id)
                            }
                            dismiss()
                        } label: {
                            Label("Delete entry", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(initial == nil ? "New entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func measureField(label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .leading)
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 26, alignment: .leading)
        }
    }

    private func save() {
        // Convert displayed values back into stored cm + kg so internal data
        // stays unit-agnostic. Empty strings → nil so partial entries don't
        // pollute the data with zeros.
        let toKg: (String) -> Double? = { s in
            guard let v = Double(s.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
            return usesMetric ? v : v / 2.20462
        }
        let toCm: (String) -> Double? = { s in
            guard let v = Double(s.replacingOccurrences(of: ",", with: ".")), v > 0 else { return nil }
            return usesMetric ? v : v * 2.54
        }

        let entry = BodyMeasurement(
            id: initial?.id ?? UUID().uuidString,
            date: date,
            weightKg: toKg(weight),
            chestCm: toCm(chest),
            waistCm: toCm(waist),
            hipsCm: toCm(hips),
            leftArmCm: toCm(leftArm),
            rightArmCm: toCm(rightArm),
            leftThighCm: toCm(leftThigh),
            rightThighCm: toCm(rightThigh),
            leftCalfCm: toCm(leftCalf),
            rightCalfCm: toCm(rightCalf),
            neckCm: toCm(neck),
            shouldersCm: toCm(shoulders),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if initial == nil {
            service.add(entry)
        } else {
            service.update(entry)
        }
    }
}

// MARK: - Helpers

extension AppState {
    /// Snapshot of the metric-units flag readable from a non-MainActor
    /// init context (the editor's `init`). UserDefaults keyed off the saved
    /// profile JSON so we don't need to bind to the AppState instance.
    nonisolated static func loadUsesMetricSnapshot() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "userProfile"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return false
        }
        return profile.usesMetric
    }
}

// FlowLayout is shared — defined in Utilities/ChipGridView.swift.
