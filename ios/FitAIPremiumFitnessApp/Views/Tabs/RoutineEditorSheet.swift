import SwiftUI

/// Build or edit a user routine. Pick exercises from the database, edit
/// sets/reps, set per-exercise rest overrides on top of a routine default.
///
/// Visual language matches `WorkoutPreviewSheet` and the routine cards —
/// indigo/purple gradient cards, top page wash, custom text fields. The
/// previous `Form`-based layout was functional but generic; this one fits
/// the app's color story.
struct RoutineEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initial: Routine?
    let onSave: (Routine?) -> Void

    @State private var name: String
    @State private var icon: String
    @State private var defaultRest: Int
    @State private var exercises: [RoutineExercise]
    @State private var showExercisePicker: Bool = false
    @State private var showAICoach: Bool = false
    @FocusState private var focusedField: Field?

    /// Stable ID for the routine being edited. Generated once at init so
    /// both the AI Coach save path (PlanModSheet writes via RoutineService)
    /// and the manual Save path use the same row — without this, a new
    /// routine going through Coach + manual save would create two rows.
    @State private var routineId: String

    private enum Field: Hashable {
        case name
        case reps(String) // exercise.id
    }

    init(initial: Routine?, onSave: @escaping (Routine?) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _name = State(initialValue: initial?.name ?? "")
        _icon = State(initialValue: initial?.icon ?? "dumbbell.fill")
        _defaultRest = State(initialValue: initial?.defaultRestSeconds ?? 90)
        _exercises = State(initialValue: initial?.exercises ?? [])
        _routineId = State(initialValue: initial?.id ?? UUID().uuidString)
    }

    private let iconOptions = ["dumbbell.fill", "figure.strengthtraining.traditional",
                                "figure.run", "figure.core.training", "flame.fill",
                                "heart.fill", "bolt.fill"]

    private let restPresets = [30, 45, 60, 75, 90, 120, 180, 240]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    nameSection
                    iconSection
                    restSection
                    exercisesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100) // room for sticky CTA
            }
            .background(pageBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(initial == nil ? "New Split" : "Edit Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        onSave(nil)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    coachButton
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(.regularMaterial)
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { picked in
                    exercises.append(RoutineExercise(
                        name: picked.name,
                        muscleGroup: picked.muscleGroup
                    ))
                }
            }
            .sheet(isPresented: $showAICoach) {
                PlanModSheet(routine: builtRoutine) { updated in
                    // Hydrate the editor's working copy with whatever the
                    // AI returned. PlanModSheet has already persisted the
                    // routine via RoutineService (with our stable routineId,
                    // so it overwrites instead of duplicating). The user
                    // can now keep tweaking manually before tapping Save,
                    // or just dismiss.
                    name = updated.name
                    icon = updated.icon
                    defaultRest = updated.defaultRestSeconds
                    exercises = updated.exercises
                }
            }
        }
    }

    /// Top-bar entry into PlanModSheet ("Modify with Coach"). Reuses the
    /// chat-driven editor the routine card kebab menu already exposes, so
    /// users get the same Coach capability without having to back out to
    /// the routine list first.
    private var coachButton: some View {
        Button {
            showAICoach = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .heavy))
                Text("Coach")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.indigo, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.18), Color.purple.opacity(0.10)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .overlay(
                Capsule().strokeBorder(Color.indigo.opacity(0.25), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showAICoach)
    }

    /// Snapshot of the in-progress edit, passed to PlanModSheet so the AI
    /// sees what the user already has (name, icon, exercises so far) and
    /// produces a diff against it. Same `routineId` as the eventual manual
    /// save so the two paths target one row in RoutineService.
    private var builtRoutine: Routine {
        Routine(
            id: routineId,
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "New Split" : name,
            icon: icon,
            exercises: exercises,
            defaultRestSeconds: defaultRest,
            createdAt: initial?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Page background

    private var pageBackground: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.10),
                    Color.purple.opacity(0.04),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .tracking(1.5)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: - Name section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Name")
            TextField("e.g. Push Day", text: $name)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .gradientCard(tint: .indigo, cornerRadius: 14)
        }
    }

    // MARK: - Icon picker

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Icon")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(iconOptions, id: \.self) { sf in
                        Button {
                            icon = sf
                        } label: {
                            iconChip(sf, selected: icon == sf)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: icon)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .gradientCard(tint: .indigo, cornerRadius: 14)
        }
    }

    private func iconChip(_ sf: String, selected: Bool) -> some View {
        ZStack {
            if selected {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.indigo.opacity(0.4), radius: 8, y: 2)
            } else {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
            }
            Image(systemName: sf)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
    }

    // MARK: - Default rest

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Default rest")
            Menu {
                ForEach(restPresets, id: \.self) { s in
                    Button(formatRest(s)) { defaultRest = s }
                }
            } label: {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.indigo.opacity(0.85))
                    Text("Rest between sets")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(formatRest(defaultRest))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .gradientCard(tint: .indigo, cornerRadius: 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("Exercises (\(exercises.count))")
                Spacer()
            }
            if exercises.isEmpty {
                emptyExercisesPlaceholder
            } else {
                VStack(spacing: 10) {
                    ForEach($exercises) { $ex in
                        exerciseCard($ex)
                    }
                }
            }
            addExerciseButton
        }
    }

    private var emptyExercisesPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No exercises yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Tap Add below to build your split.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .gradientCard(tint: .indigo, cornerRadius: 14)
    }

    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add exercise")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.indigo, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.10), Color.purple.opacity(0.04), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.35), Color.purple.opacity(0.20)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Exercise card

    private func exerciseCard(_ ex: Binding<RoutineExercise>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: name + muscle + reorder/delete
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(ex.wrappedValue.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if let group = ex.wrappedValue.supersetGroup {
                            Text("SS\(group)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(supersetColor(group), in: Capsule())
                        }
                    }
                    if !ex.wrappedValue.muscleGroup.isEmpty {
                        Text(ex.wrappedValue.muscleGroup.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                rowMenu(ex)
            }

            Divider().opacity(0.4)

            // Sets stepper row
            HStack(spacing: 12) {
                Text("Sets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                customStepper(value: ex.sets, range: 1...10)
                Spacer()
            }

            // Reps row
            HStack(spacing: 12) {
                Text("Reps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                TextField("8-12", text: ex.reps)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .reps(ex.wrappedValue.id))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(width: 110)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                focusedField == .reps(ex.wrappedValue.id)
                                    ? Color.indigo.opacity(0.5)
                                    : Color.primary.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                Spacer()
            }

            // Chip row: RPE / Rest / Superset
            HStack(spacing: 8) {
                rpeChip(ex)
                restChip(ex)
                supersetChip(ex)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .gradientCard(tint: .indigo, cornerRadius: 14)
    }

    private func rowMenu(_ ex: Binding<RoutineExercise>) -> some View {
        Menu {
            if let idx = exercises.firstIndex(where: { $0.id == ex.wrappedValue.id }), idx > 0 {
                Button {
                    exercises.swapAt(idx, idx - 1)
                } label: {
                    Label("Move up", systemImage: "arrow.up")
                }
            }
            if let idx = exercises.firstIndex(where: { $0.id == ex.wrappedValue.id }), idx < exercises.count - 1 {
                Button {
                    exercises.swapAt(idx, idx + 1)
                } label: {
                    Label("Move down", systemImage: "arrow.down")
                }
            }
            Divider()
            Button(role: .destructive) {
                exercises.removeAll { $0.id == ex.wrappedValue.id }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 26)
                .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 8))
        }
    }

    /// Plus / minus stepper with the count rendered between, since the
    /// stock SwiftUI Stepper renders flat and doesn't match the rest of
    /// the chip styling. Same affordances as the system one (long-press
    /// repeats handled via accessibility).
    private func customStepper(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 0) {
            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(value.wrappedValue > range.lowerBound ? Color.primary : Color.tertiaryLabel)
                    .frame(width: 38, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(value.wrappedValue <= range.lowerBound)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: 18)

            Text("\(value.wrappedValue)")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 36)
                .contentTransition(.numericText())

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: 18)

            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(value.wrappedValue < range.upperBound ? Color.primary : Color.tertiaryLabel)
                    .frame(width: 38, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(value.wrappedValue >= range.upperBound)
        }
        .background(Color.primary.opacity(0.06))
        .clipShape(.capsule)
        .overlay(
            Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .sensoryFeedback(.increase, trigger: value.wrappedValue)
    }

    // MARK: - Chips

    private func rpeChip(_ ex: Binding<RoutineExercise>) -> some View {
        Menu {
            Button("None") { ex.wrappedValue.targetRPE = nil }
            ForEach([6, 7, 8, 9, 10], id: \.self) { rpe in
                Button("RPE \(rpe)") { ex.wrappedValue.targetRPE = rpe }
            }
        } label: {
            let isOn = ex.wrappedValue.targetRPE != nil
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 10, weight: .bold))
                Text(ex.wrappedValue.targetRPE.map { "@\($0)" } ?? "RPE")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(isOn ? .white : Color.primary.opacity(0.85))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                if isOn {
                    Capsule().fill(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                } else {
                    Capsule().fill(Color.primary.opacity(0.06))
                }
            }
            .overlay(
                Capsule().strokeBorder(
                    isOn ? Color.clear : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
            )
        }
    }

    private func restChip(_ ex: Binding<RoutineExercise>) -> some View {
        // RestRecommender suggests a per-exercise default from movement
        // type + rep range. We surface it as a ghost-text placeholder
        // when there's no user override — no data is written, the
        // session-time recommender will compute the same value plus a
        // load-aware bump.
        let suggestion = RestRecommender.suggestedBaseline(
            exerciseName: ex.wrappedValue.name,
            repsString: ex.wrappedValue.reps
        )
        return Menu {
            Button("Auto (≈ \(formatRest(suggestion)))") {
                ex.wrappedValue.restSecondsOverride = nil
            }
            ForEach(restPresets, id: \.self) { s in
                Button(formatRest(s)) { ex.wrappedValue.restSecondsOverride = s }
            }
        } label: {
            let override = ex.wrappedValue.restSecondsOverride
            let isOverride = override != nil
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .bold))
                if isOverride {
                    Text(formatRest(override ?? suggestion))
                        .font(.caption.weight(.bold))
                } else {
                    Text("≈ \(formatRest(suggestion))")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(isOverride ? Color.indigo : Color.primary.opacity(0.55))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (isOverride ? Color.indigo.opacity(0.15) : Color.primary.opacity(0.06)),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    isOverride ? Color.indigo.opacity(0.30) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
            )
        }
    }

    private func supersetChip(_ ex: Binding<RoutineExercise>) -> some View {
        Menu {
            Button("Solo (no superset)") { ex.wrappedValue.supersetGroup = nil }
            ForEach(1...4, id: \.self) { g in
                Button("Superset \(g)") { ex.wrappedValue.supersetGroup = g }
            }
        } label: {
            let isOn = ex.wrappedValue.supersetGroup != nil
            let tint = ex.wrappedValue.supersetGroup.map(supersetColor) ?? .secondary
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .bold))
                Text(ex.wrappedValue.supersetGroup.map { "SS\($0)" } ?? "Solo")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(isOn ? tint : Color.primary.opacity(0.55))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (isOn ? tint.opacity(0.15) : Color.primary.opacity(0.06)),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    isOn ? tint.opacity(0.30) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
            )
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            let routine = Routine(
                id: routineId,
                name: name.trimmingCharacters(in: .whitespaces),
                icon: icon,
                exercises: exercises,
                defaultRestSeconds: defaultRest,
                createdAt: initial?.createdAt ?? Date(),
                updatedAt: Date()
            )
            onSave(routine)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .heavy))
                Text("Save Split")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if canSave {
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.primary.opacity(0.15)
                    }
                }
            )
            .clipShape(.rect(cornerRadius: 18))
            .shadow(color: canSave ? Color.indigo.opacity(0.35) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    // MARK: - Helpers

    /// Pick a stable color per superset group so the user can visually
    /// distinguish multiple supersets in one workout. Cycles 4 colors.
    private func supersetColor(_ group: Int) -> Color {
        switch group % 4 {
        case 1: return .blue
        case 2: return .orange
        case 3: return .purple
        default: return .green
        }
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}

private extension Color {
    /// Convenience alias — `.tertiary` doesn't exist as a Color literal, only
    /// as a ShapeStyle. Used inside the custom stepper where we need a
    /// disabled-state foreground color but in a Color-typed expression.
    static var tertiaryLabel: Color {
        Color(uiColor: UIColor.tertiaryLabel)
    }
}
