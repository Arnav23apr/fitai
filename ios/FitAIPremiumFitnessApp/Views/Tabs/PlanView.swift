import SwiftUI
import MuscleMap

struct PlanView: View {
    @Environment(AppState.self) private var appState

    private var lang: String { appState.profile.selectedLanguage }
    @State private var showCoach: Bool = false
    @State private var selectedDay: WorkoutDay? = nil
    @State private var selectedFocusItem: FocusAreaItem? = nil
    @State private var appeared: Bool = false
    @State private var coachQuestionSent: String? = nil
    @State private var hasAutoResumed: Bool = false
    @State private var selectedMuscleFromHeatmap: Muscle? = nil
    @State private var showStreakSheet: Bool = false
    @State private var showHistory: Bool = false
    @State private var showCalendar: Bool = false
    @State private var showVolumeDashboard: Bool = false
    @State private var showExercisesBrowser: Bool = false
    /// Set when the user taps a "Next PR" card; presents the per-exercise
    /// progress chart so they can drill into momentum on that lift.
    @State private var pendingInsightExercise: String? = nil
    @State private var planMode: PlanMode = .today
    @State private var showCreateRoutine: Bool = false
    @State private var routineToEdit: Routine? = nil
    @State private var activeSessionRoutine: Routine? = nil
    /// Routine queued for the pre-flight WorkoutPreviewSheet. Set when the
    /// user taps a routine card (or example template, or AI plan day) so
    /// they can review exercises before committing. The sheet's Start
    /// button then promotes this to `activeSessionRoutine`.
    @State private var routineToPreview: Routine? = nil
    @State private var showEmptyWorkoutSession: Bool = false
    @State private var showComingSoon: ComingSoonFeature? = nil
    @State private var planModRoutine: Routine? = nil
    @State private var showCreateWithCoach: Bool = false
    @State private var showPlanReview: Bool = false
    @State private var showHubPhotoScanner: Bool = false
    @State private var hubPhotoCapture: UIImage? = nil
    @State private var hubPhotoAnalysis: WeightOCRService.Result? = nil
    /// Owned at this level (not inside ActiveSessionView) so the active
    /// cover dismisses fully before the share overlay presents — fixes
    /// the cover-on-cover bug where a fresh empty session would re-launch
    /// after Finish.
    @State private var pendingShareData: WorkoutShareCardData? = nil
    /// Drives the slow breathing scale on the AI Coach FAB so it feels
    /// alive without being distracting. Set to true on appear.
    @State private var fabBreath: Bool = false
    /// Folder names currently in collapsed state. Persists in-memory only;
    /// re-expands on every app launch which keeps things simple.
    @State private var collapsedFolders: Set<String> = []
    /// Driver for the "rename folder" alert. Tied to a fileprivate sheet
    /// because alerts in iOS 26 are simpler than a bespoke sheet here.
    @State private var renamingFolder: String? = nil
    @State private var renameFolderDraft: String = ""
    /// Driver for the "move to folder" picker. When set, presents a
    /// sheet that lets the user file the routine into an existing folder
    /// or create a new one.
    @State private var movingRoutine: Routine? = nil
    @State private var clipboardImportError: String? = nil

    /// Computed view of the user's chosen workout-tab behavior.
    private var workoutMode: UserProfile.WorkoutMode { appState.profile.workoutMode }

    private let session = WorkoutSessionManager.shared
    private let routines = RoutineService.shared

    private var workoutPlan: [WorkoutDay] {
        generatePersonalizedPlan()
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var todayWorkout: WorkoutDay? {
        workoutPlan[safe: todayIndex]
    }

    private var completedCount: Int {
        appState.workoutsThisWeek
    }

    private var weeklyXP: Int {
        appState.profile.workoutLogs
            .filter {
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
            }
            .reduce(0) { $0 + 100 + ($1.exercisesCompleted * 10) }
    }

    private var nextTierPoints: Int {
        let pts = appState.profile.points
        if pts < 500 { return 500 }
        if pts < 2000 { return 2000 }
        if pts < 5000 { return 5000 }
        if pts < 10000 { return 10000 }
        return pts
    }

    private var nextTierName: String {
        let pts = appState.profile.points
        if pts < 500 { return "Silver" }
        if pts < 2000 { return "Gold" }
        if pts < 5000 { return "Platinum" }
        if pts < 10000 { return "Diamond" }
        return "Diamond"
    }

    private var daysSinceLastScan: Int? {
        guard let lastScan = appState.profile.lastScanDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastScan, to: Date()).day
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // AI users get a [Plan | Templates] segmented control
                        // so today's session and the templates list each
                        // have a clear, dedicated surface. User-built and
                        // pasted-plan users skip the segment because they
                        // don't have an AI plan to switch to.
                        switch workoutMode {
                        case .aiGenerated, .unset:
                            modeSegmentedControl
                            if planMode == .today {
                                todayGoalHero
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                planSummaryCard
                                if let suggestion = appState.pendingProgression {
                                    progressionSuggestionCard(suggestion)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                                weeklyPlanSection
                            } else {
                                routinesSection
                                PowerUserInsightsSection(
                                    usesMetric: appState.profile.usesMetric,
                                    onTapExercise: { name in
                                        pendingInsightExercise = name
                                    }
                                )
                                exampleTemplatesSection
                            }
                        case .userBuilt, .userPlanReviewed:
                            generateAIPlanCTA
                            routinesSection
                            PowerUserInsightsSection(
                                usesMetric: appState.profile.usesMetric,
                                onTapExercise: { name in
                                    pendingInsightExercise = name
                                }
                            )
                            exampleTemplatesSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                    .opacity(appeared ? 1 : 0)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .tourAutoScroll(tab: 1, proxy: scrollProxy)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .animation(.snappy(duration: 0.25), value: planMode)
            }
            .background(Color(.systemBackground))
            .overlay(alignment: .bottomTrailing) {
                aiFloatingButton
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarGlassPill
                }
            }
            .sheet(isPresented: $showCoach) {
                CoachView()
            }
            .sheet(isPresented: $showVolumeDashboard) {
                MuscleVolumeView()
            }
            .sheet(isPresented: $showExercisesBrowser) {
                ExercisesBrowserSheet()
            }
            .sheet(item: Binding<InsightExercise?>(
                get: { pendingInsightExercise.map { InsightExercise(name: $0) } },
                set: { pendingInsightExercise = $0?.name }
            )) { wrapper in
                NavigationStack {
                    ExerciseProgressChartView(
                        exerciseName: wrapper.name,
                        usesMetric: appState.profile.usesMetric
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { pendingInsightExercise = nil }
                        }
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                WorkoutHistorySheet()
            }
            .sheet(isPresented: $showCalendar) {
                WorkoutCalendarView()
            }
            .sheet(item: $selectedDay) { day in
                WorkoutDetailSheet(workout: day)
                    .interactiveDismissDisabled(false)
                    .presentationDetents([.large])
                    .presentationContentInteraction(.scrolls)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
                // Always land on Today when the user opens the Plan tab.
                // @State persists across tab switches inside TabView, so
                // without this the tab would stick on whichever mode the
                // user last selected (Advanced).
                planMode = .today
                autoResumeIfNeeded()
                checkProgressionIfDue()
            }
            .onChange(of: session.isActive) { _, newValue in
                // Don't auto-resume while a cover is already presenting,
                // otherwise we double-present (showEmptyWorkoutSession from
                // the user's tap collides with activeSessionRoutine from
                // auto-resume) and SwiftUI dismisses one, then re-presents
                // the other — visible to the user as the "screen pops up,
                // then half-pops, then opens" flicker.
                let coverAlreadyPresenting =
                    showEmptyWorkoutSession ||
                    activeSessionRoutine != nil ||
                    selectedDay != nil
                if newValue && !coverAlreadyPresenting {
                    autoResumeIfNeeded()
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                RoutineEditorSheet(initial: nil) { saved in
                    if let saved {
                        routines.save(saved)
                    }
                }
            }
            .sheet(item: $routineToEdit) { existing in
                RoutineEditorSheet(initial: existing) { saved in
                    if let saved {
                        routines.save(saved)
                    }
                }
            }
            .sheet(item: $activeSessionRoutine) { routine in
                ActiveSessionView(
                    initialName: routine.name,
                    initialIcon: routine.icon,
                    initialExercises: routine.exercises,
                    defaultRestSeconds: routine.defaultRestSeconds,
                    sourceTemplateId: routine.id,
                    onFinish: { share in
                        // Force-dismiss the active session, then queue the
                        // share overlay one runloop tick later. This is
                        // the order that prevents iOS from coalescing the
                        // two presentation changes into a re-presentation.
                        activeSessionRoutine = nil
                        if let share {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                pendingShareData = share
                            }
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $routineToPreview) { routine in
                WorkoutPreviewSheet(
                    routine: routine,
                    onStart: {
                        // Dismiss the preview first, then promote to the
                        // active session via a short delay. Same coalescing
                        // dodge the post-workout share overlay uses — without
                        // the gap, iOS sometimes merges the two presentation
                        // changes and the session never appears.
                        routineToPreview = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                            activeSessionRoutine = routine
                        }
                    },
                    onEdit: {
                        routineToPreview = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                            routineToEdit = routine
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .alert("Import failed", isPresented: Binding(
                get: { clipboardImportError != nil },
                set: { if !$0 { clipboardImportError = nil } }
            )) {
                Button("OK") { clipboardImportError = nil }
            } message: {
                Text(clipboardImportError ?? "")
            }
            .alert("Rename folder", isPresented: Binding(
                get: { renamingFolder != nil },
                set: { if !$0 { renamingFolder = nil } }
            )) {
                TextField("Folder name", text: $renameFolderDraft)
                Button("Cancel", role: .cancel) { renamingFolder = nil }
                Button("Save") {
                    if let old = renamingFolder {
                        routines.renameFolder(from: old, to: renameFolderDraft)
                    }
                    renamingFolder = nil
                }
            }
            .sheet(item: $movingRoutine) { routine in
                FolderPickerSheet(
                    currentFolder: routine.folder,
                    existingFolders: routines.allFolders,
                    onPick: { folder in
                        routines.setFolder(folder, forRoutineId: routine.id)
                        movingRoutine = nil
                    },
                    onCancel: { movingRoutine = nil }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showEmptyWorkoutSession) {
                ActiveSessionView(
                    initialName: WorkoutSessionManager.timeOfDayWorkoutName(),
                    initialIcon: "dumbbell.fill",
                    initialExercises: [],
                    defaultRestSeconds: 90,
                    sourceTemplateId: nil,
                    onFinish: { share in
                        showEmptyWorkoutSession = false
                        if let share {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                pendingShareData = share
                            }
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $pendingShareData.asIdentifiable) { wrapper in
                WorkoutShareOverlay(
                    data: wrapper.value,
                    onDismiss: { pendingShareData = nil }
                )
                .background(ClearBackground())
            }
            .fullScreenCover(isPresented: Binding(
                get: { shouldShowWorkoutOnboarding },
                set: { _ in /* dismissal happens via onChoice */ }
            )) {
                WorkoutOnboardingChoiceView { picked in
                    handleModeChoice(picked)
                }
            }
            .sheet(isPresented: $showPlanReview) {
                PlanReviewView { /* templates already saved by view */ }
            }
            .fullScreenCover(isPresented: $showHubPhotoScanner) {
                WeightScannerView(
                    onCapture: { image in
                        showHubPhotoScanner = false
                        hubPhotoCapture = image
                        Task { await analyzeHubPhoto(image) }
                    },
                    onCancel: { showHubPhotoScanner = false }
                )
            }
            .sheet(item: Binding(
                get: { hubPhotoAnalysis.map { HubPhotoResult(value: $0) } },
                set: { hubPhotoAnalysis = $0?.value }
            )) { wrapper in
                if let img = hubPhotoCapture {
                    WeightOCRConfirmSheet(
                        capturedImage: img,
                        analysis: wrapper.value,
                        onApply: { apply in
                            startSessionFromPhoto(apply)
                            hubPhotoCapture = nil
                            hubPhotoAnalysis = nil
                        }
                    )
                }
            }
            .sheet(item: $showComingSoon) { feature in
                ComingSoonSheet(feature: feature)
                    .presentationDetents([.fraction(0.55)])
            }
            .sheet(item: $planModRoutine) { rt in
                PlanModSheet(routine: rt) { _ in
                    // Routine already saved by PlanModSheet; no-op.
                }
            }
            .sheet(isPresented: $showCreateWithCoach) {
                PlanModSheet(routine: nil) { _ in
                    // Templates already saved by PlanModSheet; no-op.
                }
            }
        }
    }

    // MARK: - Quick Start
    //
    // Unified glass card: monochrome primary CTA stacked with two tinted
    // glass-style secondary CTAs (Photo log + Ask Coach). iOS 26 Liquid
    // Glass aesthetic — primary uses .glassProminent for the press +
    // shimmer feedback; secondaries use .glassEffect with tint.

    /// Combined Calendar + History pill in the nav bar. Single Liquid
    /// Glass capsule with two icon buttons separated by a hairline so
    /// the toolbar reads as one unified control instead of two loose
    /// glyphs. Falls back to a thin material on older OSes.
    private var toolbarGlassPill: some View {
        HStack(spacing: 0) {
            Button {
                showCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 0.5, height: 16)

            Button {
                showExercisesBrowser = true
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 0.5, height: 16)

            Button {
                showVolumeDashboard = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(width: 0.5, height: 16)

            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 34, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .modifier(ToolbarPillGlass())
    }

    /// "Start empty workout" sits at the top of the templates list. It's
    /// shaped like a routine card so the surface reads as a single spectrum
    /// of tap-to-launch actions (ad-hoc → saved templates), and the green
    /// icon tint differentiates it from saved templates' indigo/purple.
    private var startEmptyWorkoutRow: some View {
        Button {
            showEmptyWorkoutSession = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.18),
                                    Color.mint.opacity(0.10),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start empty workout")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("Log a one-off session without a template")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .modifier(RoutineCardGlass())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: showEmptyWorkoutSession)
    }

    /// Glass-styled secondary button used in the Quick Start row. Each
    /// gets a subtle tint to color-code the action (purple = camera,
    /// cyan = AI). Liquid Glass material in iOS 26 picks up the system
    /// background so it adapts cleanly to dark mode.
    private func quickStartSecondary(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .heavy))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .modifier(QuickStartGlass(tint: tint))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Example Templates (seeded)

    private var exampleTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Examples")
                    .font(.title3.weight(.bold))
                Text("\(routines.examples.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(routines.examples) { example in
                    exampleTemplateCard(example)
                }
            }
        }
    }

    private func exampleTemplateCard(_ routine: Routine) -> some View {
        let tint = exampleTint(for: routine)
        return Button {
            // Same preview-first behavior as user routines.
            routineToPreview = routine
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.22), tint.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                        Image(systemName: routine.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    Text("\(routine.exercises.count) ex")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(routine.exercises.prefix(3).map(\.name).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .heavy))
                    Text("Start")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(14)
            .background(
                ZStack {
                    Color.primary.opacity(0.04)
                    LinearGradient(
                        colors: [tint.opacity(0.06), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tint.opacity(0.10), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    /// Per-template accent — keeps the grid visually rhythmic without
    /// each card looking the same. Stable per routine.id so the same
    /// template always reads in the same color.
    private func exampleTint(for routine: Routine) -> Color {
        switch routine.id {
        case "example-5x5-a", "example-5x5-b": return .red
        case "example-ppl-push": return .orange
        case "example-ppl-pull": return .blue
        case "example-ppl-legs": return .purple
        case "example-upper": return .indigo
        case "example-lower": return .green
        default: return .cyan
        }
    }

    // MARK: - Coming Soon strip

    private var comingSoonStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Coming Soon")
                    .font(.title3.weight(.bold))
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    comingSoonCard(.voice)
                    comingSoonCard(.photo)
                    comingSoonCard(.appleWatch)
                }
                .padding(.horizontal, 1)
            }
            .scrollClipDisabled()
        }
        .padding(.top, 12)
    }

    private func comingSoonCard(_ feature: ComingSoonFeature) -> some View {
        Button {
            showComingSoon = feature
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [feature.tint.opacity(0.30), feature.tint.opacity(0.05), .clear],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 4,
                                endRadius: 36
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: feature.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(feature.tint)
                        .shadow(color: feature.tint.opacity(0.4), radius: 6)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(feature.headline)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Soon")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(feature.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(feature.tint.opacity(0.14))
                    )
            }
            .frame(width: 170, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .modifier(ComingSoonRowGlass(tint: feature.tint))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode segmented control
    //
    // Native SwiftUI Picker with .segmented style — same component the
    // imperial/metric picker on HeightWeightView uses. On iOS 26 this
    // automatically picks up the system Liquid Glass treatment with no
    // extra code; on older iOS it falls back to UIKit's UISegmentedControl.

    private var modeSegmentedControl: some View {
        Picker("Plan mode", selection: Binding(
            get: { planMode },
            set: { newValue in
                withAnimation(.snappy(duration: 0.22)) { planMode = newValue }
            }
        )) {
            Text("Plan").tag(PlanMode.today)
            Text("Templates").tag(PlanMode.routines)
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: planMode)
    }

    // MARK: - Routines section

    private var routinesSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("My Templates")
                    .font(.title3.weight(.bold))
                if !routines.routines.isEmpty {
                    Text("\(routines.routines.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color.primary.opacity(0.08))
                        )
                }
                Spacer()
                Menu {
                    Button {
                        showCreateRoutine = true
                    } label: {
                        Label("Build manually", systemImage: "plus")
                    }
                    Button {
                        showCreateWithCoach = true
                    } label: {
                        Label("Build with Coach", systemImage: "sparkles")
                    }
                    Button {
                        attemptClipboardImport()
                    } label: {
                        Label("Import from clipboard", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .heavy))
                        Text("New")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.primary)
                    .clipShape(.capsule)
                }
            }

            startEmptyWorkoutRow

            if routines.routines.isEmpty {
                routinesEmptyState
            } else {
                aiCoachModifyCallout
                routinesGroupedView
            }
        }
    }

    /// Groups routines by folder. Uncategorized routines render at the
    /// top with no header (treated as the default "Routines" group);
    /// folders below get a collapsible header with a count pill. Same
    /// layout pattern as Strong's "Folders" section in templates.
    @ViewBuilder
    private var routinesGroupedView: some View {
        let grouped = routines.groupedByFolder()
        ForEach(grouped.uncategorized) { routine in
            routineCard(routine)
        }
        ForEach(grouped.folders, id: \.0) { (folderName, items) in
            folderSection(name: folderName, routines: items)
        }
    }

    @ViewBuilder
    private func folderSection(name: String, routines: [Routine]) -> some View {
        let isExpanded = !collapsedFolders.contains(name)
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if collapsedFolders.contains(name) {
                    collapsedFolders.remove(name)
                } else {
                    collapsedFolders.insert(name)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.indigo)
                    Text(name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("\(routines.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                    Spacer()
                    Menu {
                        Button {
                            renamingFolder = name
                            renameFolderDraft = name
                        } label: {
                            Label("Rename folder", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            self.routines.deleteFolder(name)
                        } label: {
                            Label("Remove folder", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 28)
                    }
                }
                .padding(.top, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(routines) { routine in
                    routineCard(routine)
                }
            }
        }
    }

    /// Discovery banner for the chat-based plan editor. Surfaces above the
    /// user's templates so they realize they can ask Coach to swap
    /// exercises, change splits, etc. — instead of editing manually.
    private var aiCoachModifyCallout: some View {
        Button {
            // Open the modal on the first template — picking a specific
            // one is overkill; users can modify others via the card menu.
            if let first = routines.routines.first {
                planModRoutine = first
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.30), Color.indigo.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .indigo],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modify with AI Coach")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("Ask Coach to swap, add, or change exercises")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.purple)
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.06), Color.indigo.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.purple.opacity(0.18), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    private var routinesEmptyState: some View {
        VStack(spacing: 14) {
            // Iconified header: gradient backdrop circle behind the icon
            // so the empty state has visual weight, not just gray space.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.indigo.opacity(0.20), Color.purple.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 50
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.indigo, Color.purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.indigo.opacity(0.30), radius: 8, y: 3)
            }

            Text("No templates yet")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Build a reusable template. Pick exercises, sets, reps, and rest. Or have Coach build one for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            VStack(spacing: 8) {
                Button {
                    showCreateWithCoach = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .heavy))
                        Text("Create with Coach")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                Button {
                    showCreateRoutine = true
                } label: {
                    Text("Build manually")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .modifier(EmptyStateGlass(tint: Color.indigo))
    }

    private func routineCard(_ routine: Routine) -> some View {
        Button {
            // Tap a template → pre-flight WorkoutPreviewSheet → user
            // confirms via Start. Skips straight-to-logger so the lifter
            // can scan the exercise list before committing.
            routineToPreview = routine
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.indigo.opacity(0.18),
                                    Color.purple.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: routine.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.indigo, Color.purple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label("\(routine.exercises.count) ex", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Label("\(routine.defaultRestSeconds)s rest", systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Button { routineToEdit = routine } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button { planModRoutine = routine } label: {
                        Label("Modify with Coach", systemImage: "sparkles")
                    }
                    Button { movingRoutine = routine } label: {
                        Label(routine.folder == nil ? "Move to folder" : "Change folder", systemImage: "folder")
                    }
                    ShareLink(item: RoutineShareService.makeShareText(routine)) {
                        Label("Share template", systemImage: "square.and.arrow.up")
                    }
                    if routine.folder != nil {
                        Button {
                            routines.setFolder(nil, forRoutineId: routine.id)
                        } label: {
                            Label("Remove from folder", systemImage: "folder.badge.minus")
                        }
                    }
                    Button(role: .destructive) {
                        routines.delete(id: routine.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .modifier(RoutineCardGlass())
        }
        .buttonStyle(.plain)
    }

    /// Read the system pasteboard, look for a FitAI template payload,
    /// and import it as a new routine. Shows an error alert when the
    /// clipboard doesn't contain a valid template so the user knows
    /// the action ran (and what to fix).
    private func attemptClipboardImport() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            clipboardImportError = "Clipboard is empty. Copy a shared template first."
            return
        }
        guard let routine = RoutineShareService.decode(pasted) else {
            clipboardImportError = "We couldn't read this clipboard text as a FitAI template."
            return
        }
        if routines.atFreeCap(isPremium: appState.profile.isPremium) {
            clipboardImportError = "Free templates capped at \(RoutineService.freeTemplateCap). Upgrade or delete one to import."
            return
        }
        let saved = routines.save(routine, isPremium: appState.profile.isPremium)
        if saved {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            clipboardImportError = "Couldn't save the imported template."
        }
    }

    private func autoResumeIfNeeded() {
        guard session.isActive, !hasAutoResumed else { return }
        hasAutoResumed = true
        // Pop the user straight back into the active session via the
        // Strong-style tracker, not the legacy WorkoutDetailSheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            startWorkoutDay(session.resumedWorkoutDay())
        }
    }

    /// Unified entry point for the AI-plan "today's workout" taps. Routes
    /// through the preview sheet like the manual templates do — different
    /// source (WorkoutDay vs Routine), same UX from the user's POV.
    /// Photo-capture quick-log (startSessionFromPhoto) bypasses this and
    /// goes straight to the session, since the user already committed.
    private func startWorkoutDay(_ workout: WorkoutDay) {
        guard !workout.isRestDay else { return }
        routineToPreview = Routine(from: workout)
    }

    @MainActor
    private func analyzeHubPhoto(_ image: UIImage) async {
        let result = await WeightOCRService.shared.analyze(image: image, profile: appState.profile)
        hubPhotoAnalysis = result
    }

    /// Hub photo confirm → starts a fresh session with the detected
    /// exercise as the first card and the captured set already logged.
    private func startSessionFromPhoto(_ apply: WeightOCRConfirmSheet.Apply) {
        let routineExercise = RoutineExercise(
            name: apply.exercise,
            sets: 1,
            reps: "\(apply.reps)",
            muscleGroup: ""
        )
        let routine = Routine(
            name: WorkoutSessionManager.timeOfDayWorkoutName(),
            icon: "dumbbell.fill",
            exercises: [routineExercise],
            defaultRestSeconds: 90
        )
        // Defer one tick so the confirm sheet's dismiss has time to
        // unwind before the active session cover presents.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            activeSessionRoutine = routine
        }
    }

    /// UserDefaults gate that supersedes the profile-encoded mode for the
    /// "should we show the onboarding screen" question. Independent of
    /// the UserProfile Codable round-trip so the choice screen can't
    /// re-appear on subsequent launches even if profile decoding has any
    /// edge case with the new field.
    private static let onboardingShownKey = "workoutOnboarding.shown.v1"

    private var shouldShowWorkoutOnboarding: Bool {
        if UserDefaults.standard.bool(forKey: Self.onboardingShownKey) {
            return false
        }
        return workoutMode == .unset
    }

    /// Handles the user's choice from `WorkoutOnboardingChoiceView`.
    /// Persists both the mode (in profile) and the onboarding-shown gate
    /// (in UserDefaults) so the cover never re-appears.
    private func handleModeChoice(_ mode: UserProfile.WorkoutMode) {
        // Mark onboarding as shown FIRST so the cover dismisses on the
        // very next render, regardless of how the profile save races.
        UserDefaults.standard.set(true, forKey: Self.onboardingShownKey)

        if mode == .userPlanReviewed && !appState.profile.isPremium {
            // Pro-gated path. Fall back to userBuilt and surface paywall later.
            appState.profile.workoutMode = .userBuilt
            appState.saveProfile()
            return
        }
        appState.profile.workoutMode = mode
        appState.saveProfile()
        if mode == .userPlanReviewed {
            // Defer presentation past the cover dismissal for clean
            // transitions, same trick used in finishAndExit.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                showPlanReview = true
            }
        }
    }

    /// CTA shown when the user is in custom-templates mode but might want
    /// the AI plan after all. Generates one on tap by flipping the mode.
    private var generateAIPlanCTA: some View {
        Button {
            appState.profile.workoutMode = .aiGenerated
            appState.saveProfile()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.30), .blue.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate AI plan")
                        .font(.subheadline.weight(.bold))
                    Text("Build a 7-day program from your profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.cyan)
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.cyan.opacity(0.06), .blue.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.cyan.opacity(0.18), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan Builder Summary

    private var planSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text(L.t("yourPlanBasedOn", lang))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            let items = planBasisItems
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(item.color)
                            .frame(width: 20)
                        Text(item.text)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .modifier(PlanSummaryGlass())
        .tourAnchor(.planSummaryCard)
    }

    private var planBasisItems: [(icon: String, text: String, color: Color)] {
        var items: [(icon: String, text: String, color: Color)] = []
        if let score = appState.profile.latestScore {
            items.append(("chart.bar.fill", "Score: \(String(format: "%.1f", score))", .green))
        }
        if !appState.profile.primaryGoal.isEmpty {
            items.append(("target", appState.profile.primaryGoal, .orange))
        }
        items.append(("calendar", "\(appState.profile.workoutsPerWeek)x/week", .blue))
        if !appState.profile.weakPoints.isEmpty {
            let focus = appState.profile.weakPoints.prefix(2).joined(separator: " + ")
            items.append(("flame.fill", focus, .red))
        }
        if !appState.profile.trainingLocation.isEmpty {
            items.append(("building.2.fill", appState.profile.trainingLocation, .purple))
        }
        return items
    }

    // MARK: - Today's Goal Hero

    private var isSessionActiveForToday: Bool {
        session.isActive && !session.workoutName.isEmpty
    }

    private var todayGoalHero: some View {
        Group {
            if let workout = todayWorkout {
                let isCompleted = appState.isDayCompleted(workout.dayLabel)
                let baseAccent = workoutAccentColor(workout)
                let accentColor = isSessionActiveForToday ? Color.green : baseAccent

                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                if isSessionActiveForToday {
                                    Text("IN PROGRESS")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.green)
                                        .tracking(1.2)
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: .green.opacity(0.6), radius: 3)
                                } else {
                                    Text(L.t("todaysGoal", lang))
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(accentColor)
                                        .tracking(1.2)
                                }
                                if isCompleted {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                }
                            }

                            Text(workout.isRestDay ? L.t("restAndRecover", lang) : workout.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            if !workout.isRestDay {
                                HStack(spacing: 12) {
                                    if isSessionActiveForToday {
                                        Label(session.formatTime(session.elapsedSeconds), systemImage: "timer")
                                            .foregroundStyle(.green)
                                    } else {
                                        Label("\(estimatedMinutes(workout))min", systemImage: "clock")
                                    }
                                    Label(workoutDifficulty(workout), systemImage: "flame")
                                    Label("\(workout.exercises.count)", systemImage: "list.bullet")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if !workout.isRestDay {
                            ZStack {
                                Circle()
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 5)
                                    .frame(width: 60, height: 60)

                                let exercisesDone = isSessionActiveForToday ? session.completedCount : (isCompleted ? workout.exercises.count : 0)
                                let totalEx = isSessionActiveForToday ? session.totalExercises : workout.exercises.count
                                let progress = totalEx == 0 ? 0.0 : Double(exercisesDone) / Double(totalEx)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        accentColor,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                    )
                                    .frame(width: 60, height: 60)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(duration: 0.4), value: progress)

                                Image(systemName: isCompleted ? "checkmark" : workout.icon)
                                    .font(.system(size: isCompleted ? 18 : 20))
                                    .foregroundStyle(isCompleted ? .green : accentColor)
                            }
                        }
                    }

                    if !workout.isRestDay {
                        Divider()
                            .padding(.vertical, 14)

                        if isSessionActiveForToday {
                            HStack(spacing: 0) {
                                VStack(spacing: 2) {
                                    Text(session.formatTime(session.elapsedSeconds))
                                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                        .foregroundStyle(.green)
                                    Text("Elapsed")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)

                                Rectangle()
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(width: 1, height: 28)

                                VStack(spacing: 2) {
                                    Text("\(session.completedCount)/\(session.totalExercises)")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Text("Exercises")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)

                                Rectangle()
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(width: 1, height: 28)

                                VStack(spacing: 2) {
                                    Text(session.currentExerciseName.isEmpty ? "Done" : session.currentExerciseName)
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("Current")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            HStack(spacing: 0) {
                                VStack(spacing: 2) {
                                    Text(isCompleted ? "✓" : "+\(100 + workout.exercises.count * 10)")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(isCompleted ? .green : .yellow)
                                    Text(L.t("xpReward", lang))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)

                                Rectangle()
                                    .fill(Color.primary.opacity(0.06))
                                    .frame(width: 1, height: 28)

                                // Tier-progression stat (was "X to NextTier") removed —
                                // ranks aren't shipping in v1.

                                VStack(spacing: 2) {
                                    Text(workout.focusAreas.first ?? "–")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(L.t("target", lang))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        if !isCompleted {
                            Button(action: { startWorkoutDay(workout) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: isSessionActiveForToday ? "arrow.right.circle.fill" : "play.fill")
                                        .font(.system(size: isSessionActiveForToday ? 16 : 12))
                                    Text(isSessionActiveForToday ? L.t("resumeWorkout", lang) : L.t("startWorkout", lang))
                                        .font(.subheadline.weight(.bold))
                                    if isSessionActiveForToday {
                                        Spacer()
                                        Text(session.formatTime(session.elapsedSeconds))
                                            .font(.system(.caption, design: .monospaced, weight: .bold))
                                            .opacity(0.8)
                                    }
                                }
                                .foregroundStyle(isSessionActiveForToday ? .white : .black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    isSessionActiveForToday
                                        ? AnyShapeStyle(LinearGradient(colors: [Color.green, Color.green.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(accentColor)
                                )
                                .clipShape(.rect(cornerRadius: 14))
                            }
                            .padding(.top, 14)
                            .sensoryFeedback(.impact(weight: .medium), trigger: selectedDay?.id)
                        }
                    }
                }
                .padding(20)
                .tourAnchor(.planTodayWorkout)
                .modifier(TodayHeroGlass(
                    accent: isSessionActiveForToday ? Color.green : accentColor,
                    isActive: isSessionActiveForToday
                ))
            }
        }
    }

    // MARK: - Weekly Streak

    private var weeklyStreakSection: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    Text(L.t("weeklyStreak", lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("\(completedCount)/\(appState.profile.workoutsPerWeek)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .clipShape(.capsule)
            }

            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
            let fullLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

            HStack(spacing: 0) {
                ForEach(Array(dayLabels.enumerated()), id: \.offset) { index, label in
                    let completed = appState.isDayCompleted(fullLabels[index])
                    let isToday = index == todayIndex

                    VStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isToday ? .primary : .tertiary)

                        ZStack {
                            Circle()
                                .fill(
                                    completed ? Color.green :
                                    isToday ? Color.primary.opacity(0.12) :
                                    Color.primary.opacity(0.05)
                                )
                                .frame(width: 34, height: 34)

                            if completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.black)
                            } else if isToday {
                                Circle()
                                    .fill(Color.primary.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("Streak: \(appState.profile.currentStreak) days")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if completedCount >= appState.profile.workoutsPerWeek {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        Text(L.t("perfectWeek", lang))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                }

                Spacer()
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 18))
    }

    // MARK: - Scan Insight (Enhanced)

    private var scanInsightCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        Text(L.t("scanInsight", lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        insightBullet(icon: "target", text: "Focus on \(appState.profile.weakPoints.prefix(2).joined(separator: " & "))", color: .orange)

                        if !appState.profile.strongPoints.isEmpty {
                            insightBullet(icon: "checkmark.seal.fill", text: "\(appState.profile.strongPoints.first ?? "") looking strong", color: .green)
                        }

                        if let days = daysSinceLastScan {
                            insightBullet(icon: "clock.fill", text: "Scanned \(days) days ago", color: .blue)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f", appState.profile.latestScore ?? 0))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(L.t("score", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                bodyDiagramView

                Spacer()

                if let days = daysSinceLastScan {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: days <= 14 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(days <= 14 ? L.t("onTrack", lang) : L.t("scanOverdue", lang))
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(days <= 14 ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((days <= 14 ? Color.green : Color.orange).opacity(0.12))
                        .clipShape(.capsule)

                        Text("Consistency: \(min(100, appState.profile.totalScans * 25))%")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.06), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.green.opacity(0.1), lineWidth: 1)
        )
    }

    private func insightBullet(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var bodyDiagramView: some View {
        HStack(spacing: 4) {
            buildScanInsightBody(side: .front)
            buildScanInsightBody(side: .back)
        }
        .frame(height: 110)
    }

    private func buildScanInsightBody(side: BodySide) -> some View {
        let style = BodyViewStyle(
            defaultFillColor: Color(white: 0.22),
            strokeColor: Color(white: 0.32),
            strokeWidth: 0.3,
            selectionColor: .orange,
            selectionStrokeColor: .orange,
            selectionStrokeWidth: 1.5,
            headColor: Color(white: 0.32),
            hairColor: Color(white: 0.14)
        )
        return BodyView(gender: .male, side: side, style: style)
            .heatmap(scanMuscleIntensities(), colorScale: .workout)
            .animated(duration: 0.5)
    }

    private func scanMuscleIntensities() -> [MuscleIntensity] {
        let weakMuscles = musclesFromScanPoints(appState.profile.weakPoints)
        let strongMuscles = musclesFromScanPoints(appState.profile.strongPoints)
        let weakSet = Set(weakMuscles)
        var result: [MuscleIntensity] = weakMuscles.map { MuscleIntensity(muscle: $0, intensity: 1.0) }
        result += strongMuscles.filter { !weakSet.contains($0) }.map { MuscleIntensity(muscle: $0, intensity: 0.45) }
        return result
    }

    private func musclesFromScanPoints(_ points: [String]) -> [Muscle] {
        var muscles: [Muscle] = []
        for point in points {
            let lower = point.lowercased()
            if lower.contains("chest") { muscles.append(.chest) }
            if lower.contains("shoulder") || lower.contains("delt") { muscles.append(.deltoids) }
            if lower.contains("lower back") { muscles.append(.lowerBack) }
            else if lower.contains("back") { muscles.append(.upperBack) }
            if lower.contains("arm") { muscles.append(.biceps); muscles.append(.triceps) }
            if lower.contains("bicep") { muscles.append(.biceps) }
            if lower.contains("tricep") { muscles.append(.triceps) }
            if lower.contains("quad") || (lower.contains("leg") && !lower.contains("lower")) {
                muscles.append(.quadriceps)
            }
            if lower.contains("hamstring") { muscles.append(.hamstring) }
            if lower.contains("glute") { muscles.append(.gluteal) }
            if lower.contains("calf") || lower.contains("calve") { muscles.append(.calves) }
            if lower.contains("core") || lower.contains("ab") { muscles.append(.abs) }
            if lower.contains("oblique") { muscles.append(.obliques) }
            if lower.contains("trap") { muscles.append(.trapezius) }
            if lower.contains("forearm") { muscles.append(.forearm) }
        }
        return Array(Set(muscles))
    }

    private var promptScanCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text(L.t("scanToPersonalize", lang))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(L.t("completeScanForPlan", lang))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            ZStack {
                Color.primary.opacity(0.04)
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(colors: [.blue.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - Focus Areas (Interactive)

    private var focusAreasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text(L.t("focusAreas", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            ForEach(appState.profile.weakPoints.prefix(4), id: \.self) { point in
                let priority = focusAreaPriority(point)
                Button(action: { selectedFocusItem = FocusAreaItem(area: point) }) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(priority.color.opacity(0.12))
                                .frame(width: 44, height: 44)

                            Image(systemName: muscleGroupIcon(point))
                                .font(.system(size: 18))
                                .foregroundStyle(priority.color)
                                .symbolRenderingMode(.hierarchical)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(point)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(focusAreaSubtitle(point))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: priority.icon)
                                .font(.system(size: 9))
                            Text(priority.label)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(priority.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priority.color.opacity(0.12))
                        .clipShape(.capsule)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 14))
                }
                .sensoryFeedback(.selection, trigger: selectedFocusItem?.id)
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color.primary.opacity(0.03)
                LinearGradient(
                    colors: [.orange.opacity(0.05), .yellow.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(colors: [.orange.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    // MARK: - AI Coach Floating Button

    private var aiFloatingButton: some View {
        Menu {
            Button {
                showCoach = true
            } label: {
                Label("Open Coach Chat", systemImage: "sparkles")
            }
            if let workout = todayWorkout, !workout.isRestDay {
                Button {
                    startWorkoutDay(workout)
                } label: {
                    Label("Start Today's Workout", systemImage: "play.fill")
                }
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .modifier(AICoachGlassBackground())
                .scaleEffect(fabBreath ? 1.04 : 1.0)
                .animation(
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: fabBreath
                )
        } primaryAction: {
            showCoach = true
        }
        .padding(.trailing, 18)
        .padding(.bottom, session.isActive ? 76 : 20)
        .sensoryFeedback(.impact(weight: .light), trigger: showCoach)
        .animation(.spring(duration: 0.3), value: session.isActive)
        .onAppear { fabBreath = true }
    }

    private var dailyCoachMessage: String {
        let score = appState.profile.latestScore ?? 0
        let streak = appState.profile.currentStreak
        let weakPoints = appState.profile.weakPoints

        if streak >= 7 {
            return "Incredible streak! \(streak) days strong. Your discipline is building real results. Keep pushing through plateaus."
        }
        if score >= 7 {
            return "Your physique is trending upward. Stay consistent this week and focus on progressive overload for continued gains."
        }
        if !weakPoints.isEmpty {
            return "Your plan targets \(weakPoints.prefix(2).joined(separator: " and ")). Prioritize these areas with proper form and mind-muscle connection."
        }
        if streak >= 3 {
            return "Nice momentum with \(streak) consecutive days! Recovery is equally important. Make sure you're sleeping 7-8 hours."
        }
        return "Consistency beats intensity. Show up today and your future self will thank you. Every rep counts toward your goal."
    }

    private var suggestedQuestions: [String] {
        var questions = ["What should I eat today?"]
        if !appState.profile.weakPoints.isEmpty {
            questions.append("How do I improve \(appState.profile.weakPoints.first ?? "weak areas")?")
        }
        questions.append("Fix my weak core")
        questions.append("Best shoulder exercises?")
        return questions
    }

    // MARK: - Compete Integration

    private var competeIntegrationCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                Text(L.t("competeBonus", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                // Tier capsule hidden — ranks aren't shipping in v1.
            }

            if let workout = todayWorkout, !workout.isRestDay {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                    Text("Complete \(workout.name) to earn +\(100 + workout.exercises.count * 10) Compete points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color.yellow.opacity(0.06))
                .clipShape(.rect(cornerRadius: 10))
            }

            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(appState.profile.points)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(L.t("points", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 28)

                VStack(spacing: 2) {
                    Text("\(appState.profile.currentStreak)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.orange)
                    Text(L.t("streak", lang))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                // Rank/leaderboard-position stat hidden — ranks not shipping in v1.
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.04), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.yellow.opacity(0.08), lineWidth: 1)
        )
    }

    private var leaderboardPosition: Int {
        let pts = appState.profile.points
        if pts >= 12000 { return 1 }
        if pts >= 9000 { return 3 }
        if pts >= 5000 { return 8 }
        if pts >= 2000 { return 14 }
        if pts >= 500 { return 24 }
        return 42
    }

    // MARK: - Weekly Plan

    /// Indigo→purple gradient pill that surfaces the weekly training
    /// frequency next to the "This Week" header. Replaced the original
    /// tertiary-grey pill (low contrast, visually disconnected from the
    /// rest of the gradient story). Big rounded number anchors the eye,
    /// "/week" tail uses a softer weight so it reads as the unit.
    private var weekFrequencyBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.system(size: 10, weight: .heavy))
            HStack(spacing: 0) {
                Text("\(appState.profile.workoutsPerWeek)×")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                Text("/week")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .opacity(0.75)
            }
        }
        .foregroundStyle(
            LinearGradient(
                colors: [Color.indigo, Color.purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [
                        Color.indigo.opacity(0.18),
                        Color.purple.opacity(0.10)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        )
        .overlay(
            Capsule().strokeBorder(
                LinearGradient(
                    colors: [Color.indigo.opacity(0.35), Color.purple.opacity(0.20)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 0.5
            )
        )
        .contentTransition(.numericText())
    }

    // MARK: - Progression routine source

    /// Where the progression check + apply pull their routine list from.
    ///
    /// Priority:
    ///   1. The user's saved templates (`RoutineService.shared.routines`)
    ///      — the normal case once they've started building their own splits.
    ///   2. Synthesized routines from the procedural AI weekly plan
    ///      (`workoutPlan` → `Routine(from:)`) — fallback for users on
    ///      `.aiGenerated` mode who never explicitly saved a template.
    ///      Without this fallback, those users would never see a
    ///      progression suggestion despite being Pro and logging
    ///      workouts (the v1 bug: routines=0 short-circuited everything).
    ///
    /// Rest days are filtered out so the synthesized list only contains
    /// training days the AI can actually propose changes against.
    private func progressionRoutineSource() -> [Routine] {
        if !routines.routines.isEmpty {
            return routines.routines
        }
        return workoutPlan
            .filter { !$0.isRestDay }
            .map { Routine(from: $0) }
    }

    // MARK: - Progression suggestion (Pro, hybrid weekly check)

    /// Background-generate a progression suggestion if (a) the user is Pro,
    /// (b) we haven't already got a pending suggestion staged, (c) it's
    /// been at least 7 days since the last check. AI failures + empty
    /// suggestions are silent; no card means no card. Updates the
    /// `lastProgressionCheckAt` stamp regardless of outcome so a "no
    /// progression yet" result doesn't re-fire on every PlanView appear.
    ///
    /// `force = true` bypasses the Pro check + 7-day throttle. Used by the
    /// DEBUG "Test progression" button below so we can verify the AI + UI
    /// flow without waiting a week or simulating IAP.
    private func checkProgressionIfDue(force: Bool = false) {
        if !force {
            guard appState.profile.isPremium else { return }
            guard appState.pendingProgression == nil else { return }
            let now = Date()
            if let last = appState.profile.lastProgressionCheckAt,
               now.timeIntervalSince(last) < 7 * 24 * 3600 {
                return
            }
        }
        let profile = appState.profile
        let allLogs = ExerciseLogService.shared.loadAll()
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let recentLogs = allLogs.filter { $0.date >= cutoff }
        let routinesList = progressionRoutineSource()
        #if DEBUG
        let synthetic = routines.routines.isEmpty && !routinesList.isEmpty
        print("[Progression] starting check, force=\(force), recentLogs=\(recentLogs.count), routines=\(routinesList.count)\(synthetic ? " (synthesized from AI plan)" : "")")
        #endif
        Task { @MainActor in
            let suggestion = await ProgressionService.shared.generateSuggestion(
                profile: profile,
                recentLogs: recentLogs,
                routines: routinesList
            )
            appState.profile.lastProgressionCheckAt = Date()
            appState.saveProfile()
            #if DEBUG
            if let s = suggestion {
                print("[Progression] suggestion received: '\(s.headline)' with \(s.changes.count) changes")
                for change in s.changes {
                    print("[Progression]   • \(change.exerciseName): \(change.label)")
                }
            } else {
                print("[Progression] AI returned nil (empty changes, parse failure, or AI failure)")
            }
            #endif
            if let suggestion {
                withAnimation(.snappy(duration: 0.4)) {
                    appState.pendingProgression = suggestion
                }
            }
        }
    }


    /// Indigo→purple gradient card. Two render modes:
    ///   - **Proposal**: AI has concrete progression changes to apply.
    ///     Shows top-3 change bullets + Apply / Keep current buttons.
    ///   - **Insight**: AI looked at the data and decided not to propose
    ///     changes (insufficient logs, missed reps, ambiguous signal).
    ///     Shows the AI's reasoning + a single "Got it" dismiss. Without
    ///     this branch, users tap the trigger and get silence with no
    ///     context — they assume it's broken.
    private func progressionSuggestionCard(_ suggestion: ProgressionSuggestion) -> some View {
        let hasChanges = !suggestion.changes.isEmpty
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.30), Color.purple.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: hasChanges ? "sparkles" : "checklist")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.indigo, Color.purple],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(hasChanges ? "COACH SUGGESTION" : "COACH CHECK-IN")
                        .font(.system(size: 10, weight: .black))
                        .tracking(1.5)
                        .foregroundStyle(.purple)
                    Text(suggestion.headline)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    if !suggestion.summary.isEmpty {
                        Text(suggestion.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            if hasChanges {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestion.changes.prefix(3)) { change in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Color.indigo)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(change.exerciseName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(change.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: 10))
            }

            if hasChanges {
                progressionProposalActions(suggestion)
            } else {
                progressionInsightActions
            }
        }
        .padding(14)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                LinearGradient(
                    colors: [Color.indigo.opacity(0.12), Color.purple.opacity(0.05), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.30), Color.purple.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.6
                )
        )
    }

    /// Apply / Keep current button row — proposal mode (changes present).
    private func progressionProposalActions(_ suggestion: ProgressionSuggestion) -> some View {
        HStack(spacing: 8) {
            Button {
                let target = progressionRoutineSource()
                let count = ProgressionService.shared.apply(suggestion, against: target)
                withAnimation(.snappy(duration: 0.3)) {
                    appState.pendingProgression = nil
                }
                if count > 0 {
                    appState.showBanner(
                        InAppBanner(
                            title: "Progression applied",
                            subtitle: "Updated \(count) exercise\(count == 1 ? "" : "s").",
                            icon: "sparkles",
                            iconTint: .purple
                        )
                    )
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                    Text("Apply")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.indigo, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .capsule
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    appState.pendingProgression = nil
                }
            } label: {
                Text("Keep current")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.08), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    /// Single dismiss row — insight mode (no concrete progression yet).
    /// The card's summary already told the user what to do next; this
    /// just acknowledges and tucks it away until next week's check.
    private var progressionInsightActions: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) {
                appState.pendingProgression = nil
            }
        } label: {
            Text("Got it")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.indigo, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .capsule
                )
        }
        .buttonStyle(.plain)
    }

    private var weeklyPlanSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text(L.t("thisWeek", lang))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                weekFrequencyBadge
            }

            ForEach(Array(workoutPlan.enumerated()), id: \.element.id) { index, workout in
                Button(action: {
                    // Route through ActiveSessionView (same path as Today's
                    // hero card and Templates) so the in-session logging UX
                    // including StrongKeypad is identical across every entry
                    // point. The legacy WorkoutDetailSheet path used the iOS
                    // decimal pad — inconsistent with the rest of the app.
                    if !workout.isRestDay {
                        startWorkoutDay(workout)
                    }
                }) {
                    workoutRow(workout, isToday: index == todayIndex, cardIndex: index)
                }
                .disabled(workout.isRestDay)
                .sensoryFeedback(.selection, trigger: activeSessionRoutine?.id)
            }
        }
    }

    private func workoutRow(_ workout: WorkoutDay, isToday: Bool, cardIndex: Int) -> some View {
        let completed = appState.isDayCompleted(workout.dayLabel)
        let accentColor = workoutAccentColor(workout)
        let bgColor: Color = completed ? Color.green.opacity(0.04) : (isToday ? accentColor.opacity(0.06) : Color.primary.opacity(0.04))

        return VStack(spacing: 0) {
            workoutRowMain(workout: workout, isToday: isToday, completed: completed, accentColor: accentColor)
            workoutRowMuscles(workout: workout, completed: completed)
        }
        .background(bgColor)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            isToday && !completed ?
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.15), lineWidth: 1) : nil
        )
        .opacity(completed ? 0.75 : 1)
        .animation(.spring(duration: 0.35), value: completed)
    }

    private func workoutRowMain(workout: WorkoutDay, isToday: Bool, completed: Bool, accentColor: Color) -> some View {
        let totalSetsCount = workout.exercises.reduce(0) { $0 + $1.sets }
        let xpReward = 100 + workout.exercises.count * 10

        return HStack(spacing: 14) {
            workoutDayLabel(dayLabel: workout.dayLabel, isToday: isToday, accentColor: accentColor)
            workoutIcon(workout: workout, completed: completed, accentColor: accentColor)
            workoutInfo(workout: workout, completed: completed, totalSetsCount: totalSetsCount)
            Spacer()
            if !workout.isRestDay {
                workoutTrailing(workout: workout, completed: completed, accentColor: accentColor, xpReward: xpReward)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func workoutDayLabel(dayLabel: String, isToday: Bool, accentColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(dayLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isToday ? .primary : .tertiary)
            if isToday {
                Circle()
                    .fill(accentColor)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 32)
    }

    private func workoutIcon(workout: WorkoutDay, completed: Bool, accentColor: Color) -> some View {
        let iconColor: Color = completed ? .green : (workout.isRestDay ? Color(.tertiaryLabel) : accentColor)
        let iconBg: Color = completed ? Color.green.opacity(0.12) : accentColor.opacity(0.12)

        return ZStack {
            Image(systemName: workout.icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 42, height: 42)
                .background(iconBg)
                .clipShape(Circle())

            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .background(Circle().fill(Color(.systemBackground)).frame(width: 12, height: 12))
                    .offset(x: 16, y: 16)
            }
        }
    }

    private func workoutInfo(workout: WorkoutDay, completed: Bool, totalSetsCount: Int) -> some View {
        let nameColor: Color = completed ? .secondary : (workout.isRestDay ? Color(.tertiaryLabel) : .primary)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(nameColor)
                if completed {
                    workoutBadge(text: L.t("doneLabel", lang), color: .green)
                } else if workout.isWeakPointFocus {
                    workoutBadge(text: L.t("focusLabel", lang), color: .orange)
                }
            }

            if !workout.isRestDay {
                HStack(spacing: 6) {
                    Label("\(estimatedMinutes(workout))m", systemImage: "clock")
                    Label("\(totalSetsCount)", systemImage: "square.stack.fill")
                    Label("\(workout.exercises.count)", systemImage: "list.bullet")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            } else {
                Text(workout.focusAreas.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private func workoutBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(.capsule)
    }

    private func workoutTrailing(workout: WorkoutDay, completed: Bool, accentColor: Color, xpReward: Int) -> some View {
        let diff = workoutDifficultyLevel(workout)
        return HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < diff ? accentColor : Color.primary.opacity(0.08))
                            .frame(width: 4, height: 4)
                    }
                }
                if !completed {
                    Text("+\(xpReward)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(.capsule)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
    }

    @ViewBuilder
    private func workoutRowMuscles(workout: WorkoutDay, completed: Bool) -> some View {
        if !workout.isRestDay && !completed {
            let muscles = Array(Set(workout.exercises.map(\.muscleGroup))).prefix(3)
            HStack(spacing: 6) {
                ForEach(Array(muscles), id: \.self) { muscle in
                    let isWeak = appState.profile.weakPoints.contains(where: { $0.lowercased() == muscle.lowercased() })
                    let chipColor: Color = isWeak ? .orange : Color(.quaternaryLabel)
                    let chipBg: Color = isWeak ? Color.orange.opacity(0.08) : Color.primary.opacity(0.03)
                    Text(muscle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(chipColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(chipBg)
                        .clipShape(.capsule)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    private func workoutDifficultyLevel(_ workout: WorkoutDay) -> Int {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets }
        if totalSets >= 24 { return 5 }
        if totalSets >= 20 { return 4 }
        if totalSets >= 14 { return 3 }
        if totalSets >= 8 { return 2 }
        return 1
    }

    // MARK: - Next Scan Reminder

    private var nextScanReminderCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18))
                        .foregroundStyle(.purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let days = daysSinceLastScan {
                        let remaining = max(14 - days, 0)
                        Text(remaining > 0 ? L.t("nextScanDays", lang).replacingOccurrences(of: "%@", with: "\(remaining)") : L.t("timeForNewScan", lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L.t("keepConsistent", lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L.t("completeFirstScan", lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L.t("trackProgress", lang))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.06), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.purple.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Weekly Summary

    private var weeklySummaryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.mint)
                Text(L.t("thisWeek", lang))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 0) {
                summaryItem(
                    value: "\(completedCount)/\(appState.profile.workoutsPerWeek)",
                    label: L.t("workouts", lang),
                    color: .green
                )
                summaryDivider
                summaryItem(
                    value: "\(appState.profile.currentStreak)",
                    label: L.t("dayStreak", lang),
                    color: .orange
                )
                summaryDivider
                summaryItem(
                    value: "\(weeklyXP)",
                    label: L.t("xpEarned", lang),
                    color: .yellow
                )
            }

            if !appState.profile.weakPoints.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("\(L.t("improvementAreas", lang)): \(appState.profile.weakPoints.prefix(2).joined(separator: " + "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(10)
                .background(Color.cyan.opacity(0.05))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color.primary.opacity(0.04)
                LinearGradient(
                    colors: [.cyan.opacity(0.04), .blue.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(colors: [.cyan.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 28)
    }

    // MARK: - Helpers

    private func workoutAccentColor(_ workout: WorkoutDay) -> Color {
        if workout.isRestDay { return .gray }
        let name = workout.name.lowercased()
        if name.contains("push") { return .red }
        if name.contains("pull") { return .blue }
        if name.contains("leg") { return .purple }
        if name.contains("upper") { return .cyan }
        if name.contains("lower") || name.contains("core") { return .orange }
        if name.contains("recovery") { return .teal }
        if name.contains("weak") || name.contains("focus") { return .orange }
        if name.contains("full") { return .green }
        return .blue
    }

    private func estimatedMinutes(_ workout: WorkoutDay) -> Int {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets }
        return max(totalSets * 3, 15)
    }

    private func workoutDifficulty(_ workout: WorkoutDay) -> String {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets }
        if totalSets >= 20 { return "Hard" }
        if totalSets >= 12 { return "Medium" }
        return "Easy"
    }

    private func muscleGroupIcon(_ area: String) -> String {
        let lower = area.lowercased()
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("shoulder") || lower.contains("delt") { return "figure.boxing" }
        if lower.contains("back") || lower.contains("lat") { return "figure.rowing" }
        if lower.contains("arm") || lower.contains("bicep") || lower.contains("tricep") { return "figure.arms.open" }
        if lower.contains("leg") || lower.contains("quad") || lower.contains("hamstring") || lower.contains("calf") || lower.contains("calves") { return "figure.run" }
        if lower.contains("glute") { return "figure.stairs" }
        if lower.contains("core") || lower.contains("ab") { return "figure.core.training" }
        if lower.contains("body fat") || lower.contains("fat") { return "flame.fill" }
        if lower.contains("definition") || lower.contains("muscle") { return "figure.highintensity.intervaltraining" }
        return "figure.mixed.cardio"
    }

    private func focusAreaPriority(_ area: String) -> FocusAreaPriority {
        let weakPoints = appState.profile.weakPoints
        guard let index = weakPoints.firstIndex(of: area) else { return .maintaining }
        if index == 0 { return .high }
        if index <= 1 { return .moderate }
        return .maintaining
    }

    private func focusAreaScore(_ area: String) -> Double {
        let base = appState.profile.latestScore ?? 5.0
        let priority = focusAreaPriority(area)
        switch priority {
        case .high: return max(base - 2.0, 1.0)
        case .moderate: return max(base - 1.0, 2.0)
        case .maintaining: return base
        }
    }

    private func focusAreaSubtitle(_ area: String) -> String {
        let lower = area.lowercased()
        if lower.contains("shoulder") { return "Wider frame, better posture" }
        if lower.contains("chest") { return "Upper body pressing power" }
        if lower.contains("back") { return "V-taper and posture" }
        if lower.contains("arm") { return "Complete physique" }
        if lower.contains("leg") { return "Foundation of strength" }
        if lower.contains("glute") { return "Hip power and stability" }
        if lower.contains("core") || lower.contains("ab") { return "Stability and protection" }
        if lower.contains("calf") { return "Lower body completion" }
        return "Targeted improvement area"
    }

    private func focusAreaExercises(_ area: String) -> [String] {
        let lower = area.lowercased()
        let isGym = appState.profile.trainingLocation.lowercased().contains("gym")
        if lower.contains("shoulder") {
            return isGym ? ["Overhead Press", "Lateral Raises", "Face Pulls", "Arnold Press", "Rear Delt Flyes"] : ["Pike Push-Ups", "Lateral Raises", "Band Pull-Aparts", "Handstand Progression"]
        }
        if lower.contains("chest") {
            return isGym ? ["Bench Press", "Incline DB Press", "Cable Flyes", "Dips", "Push-Ups"] : ["Push-Ups", "Decline Push-Ups", "Wide Push-Ups", "Dips"]
        }
        if lower.contains("back") {
            return isGym ? ["Barbell Rows", "Lat Pulldown", "Cable Row", "Face Pulls", "Deadlift"] : ["Pull-Ups", "Inverted Rows", "Superman Hold", "Band Rows"]
        }
        if lower.contains("leg") {
            return isGym ? ["Squats", "Romanian Deadlift", "Leg Press", "Lunges", "Calf Raises"] : ["Bulgarian Split Squats", "Pistol Squats", "Jump Squats", "Wall Sits"]
        }
        if lower.contains("core") || lower.contains("ab") {
            return ["Planks", "Hanging Leg Raises", "Cable Crunches", "Bicycle Crunches", "Ab Wheel"]
        }
        return ["Targeted Volume Work", "Progressive Overload", "Mind-Muscle Connection"]
    }

    // MARK: - Exercises helpers

    private func exerciseIcon(_ muscleGroup: String) -> String {
        let lower = muscleGroup.lowercased()
        if lower.contains("chest") { return "figure.strengthtraining.traditional" }
        if lower.contains("shoulder") || lower.contains("delt") { return "figure.boxing" }
        if lower.contains("back") || lower.contains("lat") { return "figure.rowing" }
        if lower.contains("bicep") || lower.contains("curl") { return "figure.arms.open" }
        if lower.contains("tricep") { return "figure.arms.open" }
        if lower.contains("quad") || lower.contains("leg") { return "figure.run" }
        if lower.contains("hamstring") { return "figure.run" }
        if lower.contains("glute") { return "figure.stairs" }
        if lower.contains("calf") || lower.contains("calves") { return "figure.run" }
        if lower.contains("core") || lower.contains("ab") || lower.contains("oblique") { return "figure.core.training" }
        if lower.contains("cardio") { return "figure.run" }
        if lower.contains("hip") { return "figure.flexibility" }
        if lower.contains("spine") { return "figure.mind.and.body" }
        if lower.contains("full body") { return "figure.mixed.cardio" }
        return "dumbbell.fill"
    }

    // MARK: - Plan Generation (unchanged logic)

    private func generatePersonalizedPlan() -> [WorkoutDay] {
        let weakPoints = appState.profile.weakPoints
        let location = appState.profile.trainingLocation
        let perWeek = appState.profile.workoutsPerWeek

        let hasWeakPoints = !weakPoints.isEmpty
        let isGym = location.lowercased().contains("gym")

        let weakLower = weakPoints.contains(where: { ["Legs", "Glutes", "Calves"].contains($0) })
        let weakUpper = weakPoints.contains(where: { ["Chest", "Back", "Shoulders", "Arms"].contains($0) })
        let weakCore = weakPoints.contains(where: { ["Core", "Abs"].contains($0) })

        var days: [WorkoutDay] = []

        let dayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

        if perWeek >= 5 {
            days = [
                buildPushDay(isGym: isGym, weakFocus: weakPoints.contains("Shoulders") || weakPoints.contains("Chest")),
                buildPullDay(isGym: isGym, weakFocus: weakPoints.contains("Back")),
                buildLegDay(isGym: isGym, weakFocus: weakLower),
                buildUpperDay(isGym: isGym, weakFocus: weakUpper),
                buildLowerCorDay(isGym: isGym, weakFocus: weakLower || weakCore),
                WorkoutDay(dayLabel: "SAT", name: "Active Recovery", focusAreas: ["Mobility", "Light Cardio"], icon: "figure.cooldown", isRestDay: false, exercises: recoveryExercises()),
                WorkoutDay(dayLabel: "SUN", name: "Rest", focusAreas: ["Full Recovery"], icon: "bed.double.fill", isRestDay: true),
            ]
        } else if perWeek >= 3 {
            days = [
                buildPushDay(isGym: isGym, weakFocus: weakUpper),
                WorkoutDay(dayLabel: "TUE", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                buildPullDay(isGym: isGym, weakFocus: weakPoints.contains("Back")),
                WorkoutDay(dayLabel: "THU", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                buildLegDay(isGym: isGym, weakFocus: weakLower),
                hasWeakPoints ?
                    buildWeakPointDay(weakPoints: weakPoints, isGym: isGym) :
                    WorkoutDay(dayLabel: "SAT", name: "Active Recovery", focusAreas: ["Mobility"], icon: "figure.cooldown", isRestDay: false, exercises: recoveryExercises()),
                WorkoutDay(dayLabel: "SUN", name: "Rest", focusAreas: ["Full Recovery"], icon: "bed.double.fill", isRestDay: true),
            ]
        } else {
            days = [
                buildFullBodyDay(isGym: isGym, weakFocus: hasWeakPoints, label: "MON"),
                WorkoutDay(dayLabel: "TUE", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                WorkoutDay(dayLabel: "WED", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                buildFullBodyDay(isGym: isGym, weakFocus: hasWeakPoints, label: "THU"),
                WorkoutDay(dayLabel: "FRI", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                WorkoutDay(dayLabel: "SAT", name: "Rest", focusAreas: ["Recovery"], icon: "bed.double.fill", isRestDay: true),
                WorkoutDay(dayLabel: "SUN", name: "Rest", focusAreas: ["Full Recovery"], icon: "bed.double.fill", isRestDay: true),
            ]
        }

        for i in 0..<days.count {
            days[i] = WorkoutDay(
                id: days[i].id,
                dayLabel: dayLabels[i],
                name: days[i].name,
                focusAreas: days[i].focusAreas,
                icon: days[i].icon,
                isRestDay: days[i].isRestDay,
                exercises: days[i].exercises,
                isWeakPointFocus: days[i].isWeakPointFocus
            )
        }

        // Re-slot workouts onto the user's preferred training days when
        // they've picked them and the count matches their stated weekly
        // volume. Otherwise the default Mon-first cadence above stays.
        if let preferred = appState.profile.preferredTrainingDays,
           !preferred.isEmpty,
           preferred.count == perWeek {
            days = reslotForPreferredDays(days, preferred: Set(preferred), labels: dayLabels)
        }

        return days
    }

    /// Place the existing non-rest sessions onto the user's preferred
    /// slots in their original order, fill the rest of the week with
    /// "Rest" days. Keeps the planner's training-day sequence (push →
    /// pull → legs etc.) intact while honoring the user's schedule.
    private func reslotForPreferredDays(
        _ original: [WorkoutDay],
        preferred: Set<String>,
        labels: [String]
    ) -> [WorkoutDay] {
        let workoutQueue = original.filter { !$0.isRestDay }
        var queueIndex = 0
        var rebuilt: [WorkoutDay] = []
        for label in labels {
            if preferred.contains(label), queueIndex < workoutQueue.count {
                let src = workoutQueue[queueIndex]
                rebuilt.append(WorkoutDay(
                    id: src.id,
                    dayLabel: label,
                    name: src.name,
                    focusAreas: src.focusAreas,
                    icon: src.icon,
                    isRestDay: false,
                    exercises: src.exercises,
                    isWeakPointFocus: src.isWeakPointFocus
                ))
                queueIndex += 1
            } else {
                rebuilt.append(WorkoutDay(
                    dayLabel: label,
                    name: "Rest",
                    focusAreas: ["Recovery"],
                    icon: "bed.double.fill",
                    isRestDay: true
                ))
            }
        }
        return rebuilt
    }

    private func buildPushDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Barbell Bench Press", sets: 4, reps: "8-10", muscleGroup: "Chest"),
            Exercise(name: "Incline Dumbbell Press", sets: 3, reps: "10-12", muscleGroup: "Upper Chest"),
            Exercise(name: "Overhead Press", sets: 4, reps: "8-10", muscleGroup: "Shoulders"),
            Exercise(name: "Lateral Raises", sets: 3, reps: "12-15", muscleGroup: "Side Delts"),
            Exercise(name: "Cable Flyes", sets: 3, reps: "12-15", muscleGroup: "Chest"),
            Exercise(name: "Tricep Pushdowns", sets: 3, reps: "12-15", muscleGroup: "Triceps"),
        ] : [
            Exercise(name: "Push-Ups", sets: 4, reps: "15-20", muscleGroup: "Chest"),
            Exercise(name: "Pike Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Diamond Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
            Exercise(name: "Dips (Chair)", sets: 3, reps: "12-15", muscleGroup: "Chest/Triceps"),
            Exercise(name: "Decline Push-Ups", sets: 3, reps: "12-15", muscleGroup: "Upper Chest"),
        ]
        return WorkoutDay(dayLabel: "MON", name: "Push Day", focusAreas: ["Chest", "Shoulders", "Triceps"], icon: "figure.strengthtraining.traditional", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildPullDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Barbell Rows", sets: 4, reps: "8-10", muscleGroup: "Back"),
            Exercise(name: "Lat Pulldown", sets: 3, reps: "10-12", muscleGroup: "Lats"),
            Exercise(name: "Face Pulls", sets: 3, reps: "15-20", muscleGroup: "Rear Delts"),
            Exercise(name: "Seated Cable Row", sets: 3, reps: "10-12", muscleGroup: "Mid Back"),
            Exercise(name: "Barbell Curls", sets: 3, reps: "10-12", muscleGroup: "Biceps"),
            Exercise(name: "Hammer Curls", sets: 3, reps: "12-15", muscleGroup: "Biceps"),
        ] : [
            Exercise(name: "Pull-Ups", sets: 4, reps: "6-10", muscleGroup: "Back"),
            Exercise(name: "Inverted Rows", sets: 3, reps: "10-12", muscleGroup: "Mid Back"),
            Exercise(name: "Superman Hold", sets: 3, reps: "30s", muscleGroup: "Lower Back"),
            Exercise(name: "Band Face Pulls", sets: 3, reps: "15-20", muscleGroup: "Rear Delts"),
            Exercise(name: "Doorway Curls", sets: 3, reps: "12-15", muscleGroup: "Biceps"),
        ]
        return WorkoutDay(dayLabel: "TUE", name: "Pull Day", focusAreas: ["Back", "Biceps", "Rear Delts"], icon: "figure.strengthtraining.functional", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildLegDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Barbell Squat", sets: 4, reps: "8-10", muscleGroup: "Quads"),
            Exercise(name: "Romanian Deadlift", sets: 4, reps: "8-10", muscleGroup: "Hamstrings"),
            Exercise(name: "Leg Press", sets: 3, reps: "10-12", muscleGroup: "Quads"),
            Exercise(name: "Walking Lunges", sets: 3, reps: "12/leg", muscleGroup: "Glutes"),
            Exercise(name: "Calf Raises", sets: 4, reps: "15-20", muscleGroup: "Calves"),
            Exercise(name: "Leg Curl", sets: 3, reps: "12-15", muscleGroup: "Hamstrings"),
        ] : [
            Exercise(name: "Bulgarian Split Squats", sets: 4, reps: "10/leg", muscleGroup: "Quads"),
            Exercise(name: "Glute Bridges", sets: 4, reps: "15-20", muscleGroup: "Glutes"),
            Exercise(name: "Jump Squats", sets: 3, reps: "12-15", muscleGroup: "Quads"),
            Exercise(name: "Single Leg RDL", sets: 3, reps: "10/leg", muscleGroup: "Hamstrings"),
            Exercise(name: "Wall Sit", sets: 3, reps: "45s", muscleGroup: "Quads"),
        ]
        return WorkoutDay(dayLabel: "WED", name: "Legs", focusAreas: ["Quads", "Hamstrings", "Glutes"], icon: "figure.run", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildUpperDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Dumbbell Bench Press", sets: 3, reps: "10-12", muscleGroup: "Chest"),
            Exercise(name: "Cable Rows", sets: 3, reps: "10-12", muscleGroup: "Back"),
            Exercise(name: "Arnold Press", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Incline Curls", sets: 3, reps: "12-15", muscleGroup: "Biceps"),
            Exercise(name: "Overhead Tricep Extension", sets: 3, reps: "12-15", muscleGroup: "Triceps"),
        ] : [
            Exercise(name: "Push-Ups", sets: 3, reps: "15-20", muscleGroup: "Chest"),
            Exercise(name: "Inverted Rows", sets: 3, reps: "10-12", muscleGroup: "Back"),
            Exercise(name: "Pike Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Chin-Ups", sets: 3, reps: "6-10", muscleGroup: "Biceps"),
            Exercise(name: "Diamond Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
        ]
        return WorkoutDay(dayLabel: "THU", name: "Upper Body", focusAreas: ["Chest", "Back", "Arms"], icon: "figure.mixed.cardio", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildLowerCorDay(isGym: Bool, weakFocus: Bool) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Front Squats", sets: 4, reps: "8-10", muscleGroup: "Quads"),
            Exercise(name: "Hip Thrusts", sets: 4, reps: "10-12", muscleGroup: "Glutes"),
            Exercise(name: "Leg Extensions", sets: 3, reps: "12-15", muscleGroup: "Quads"),
            Exercise(name: "Hanging Leg Raises", sets: 3, reps: "12-15", muscleGroup: "Core"),
            Exercise(name: "Cable Woodchops", sets: 3, reps: "12/side", muscleGroup: "Obliques"),
        ] : [
            Exercise(name: "Pistol Squat Progression", sets: 3, reps: "8/leg", muscleGroup: "Quads"),
            Exercise(name: "Single Leg Glute Bridge", sets: 3, reps: "12/leg", muscleGroup: "Glutes"),
            Exercise(name: "Plank", sets: 3, reps: "60s", muscleGroup: "Core"),
            Exercise(name: "Bicycle Crunches", sets: 3, reps: "20", muscleGroup: "Obliques"),
            Exercise(name: "Mountain Climbers", sets: 3, reps: "30s", muscleGroup: "Core"),
        ]
        return WorkoutDay(dayLabel: "FRI", name: "Lower + Core", focusAreas: ["Legs", "Glutes", "Core"], icon: "figure.core.training", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func buildWeakPointDay(weakPoints: [String], isGym: Bool) -> WorkoutDay {
        var exercises: [Exercise] = []
        for point in weakPoints.prefix(3) {
            switch point {
            case "Shoulders":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Overhead Press" : "Pike Push-Ups", sets: 4, reps: "10-12", muscleGroup: "Shoulders"),
                    Exercise(name: "Lateral Raises", sets: 4, reps: "15-20", muscleGroup: "Side Delts"),
                ])
            case "Chest":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Incline Bench Press" : "Decline Push-Ups", sets: 4, reps: "10-12", muscleGroup: "Chest"),
                    Exercise(name: isGym ? "Cable Crossovers" : "Wide Push-Ups", sets: 3, reps: "12-15", muscleGroup: "Chest"),
                ])
            case "Back":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "T-Bar Row" : "Inverted Rows", sets: 4, reps: "10-12", muscleGroup: "Back"),
                    Exercise(name: isGym ? "Straight Arm Pulldown" : "Superman Hold", sets: 3, reps: isGym ? "12-15" : "30s", muscleGroup: "Back"),
                ])
            case "Legs", "Glutes", "Calves":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Hack Squat" : "Pistol Squats", sets: 4, reps: "10-12", muscleGroup: "Quads"),
                    Exercise(name: isGym ? "Seated Calf Raise" : "Single Leg Calf Raise", sets: 4, reps: "15-20", muscleGroup: "Calves"),
                ])
            case "Arms":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Preacher Curls" : "Chin-Ups", sets: 3, reps: "10-12", muscleGroup: "Biceps"),
                    Exercise(name: isGym ? "Skull Crushers" : "Diamond Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Triceps"),
                ])
            case "Core", "Abs":
                exercises.append(contentsOf: [
                    Exercise(name: isGym ? "Cable Crunches" : "Hanging Knee Raises", sets: 3, reps: "15-20", muscleGroup: "Core"),
                    Exercise(name: "Plank", sets: 3, reps: "60s", muscleGroup: "Core"),
                ])
            default:
                exercises.append(Exercise(name: "Extra Volume Work", sets: 3, reps: "12-15", muscleGroup: point))
            }
        }
        return WorkoutDay(dayLabel: "SAT", name: "Weak Point Focus", focusAreas: weakPoints, icon: "target", isRestDay: false, exercises: exercises, isWeakPointFocus: true)
    }

    private func buildFullBodyDay(isGym: Bool, weakFocus: Bool, label: String) -> WorkoutDay {
        let exercises = isGym ? [
            Exercise(name: "Squat", sets: 3, reps: "8-10", muscleGroup: "Legs"),
            Exercise(name: "Bench Press", sets: 3, reps: "8-10", muscleGroup: "Chest"),
            Exercise(name: "Barbell Row", sets: 3, reps: "8-10", muscleGroup: "Back"),
            Exercise(name: "Overhead Press", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Plank", sets: 3, reps: "45s", muscleGroup: "Core"),
        ] : [
            Exercise(name: "Bodyweight Squat", sets: 3, reps: "15-20", muscleGroup: "Legs"),
            Exercise(name: "Push-Ups", sets: 3, reps: "15-20", muscleGroup: "Chest"),
            Exercise(name: "Inverted Rows", sets: 3, reps: "10-12", muscleGroup: "Back"),
            Exercise(name: "Pike Push-Ups", sets: 3, reps: "10-12", muscleGroup: "Shoulders"),
            Exercise(name: "Plank", sets: 3, reps: "45s", muscleGroup: "Core"),
        ]
        return WorkoutDay(dayLabel: label, name: "Full Body", focusAreas: ["Total Body"], icon: "figure.strengthtraining.traditional", exercises: exercises, isWeakPointFocus: weakFocus)
    }

    private func recoveryExercises() -> [Exercise] {
        [
            Exercise(name: "Foam Rolling", sets: 1, reps: "10min", muscleGroup: "Full Body"),
            Exercise(name: "Hip Flexor Stretch", sets: 2, reps: "60s/side", muscleGroup: "Hips"),
            Exercise(name: "Cat-Cow Stretch", sets: 2, reps: "10", muscleGroup: "Spine"),
            Exercise(name: "Light Walk", sets: 1, reps: "20min", muscleGroup: "Cardio"),
        ]
    }
}

nonisolated struct FocusAreaItem: Identifiable, Sendable {
    let id: String
    let area: String

    init(area: String) {
        self.id = area
        self.area = area
    }
}

extension Array where Element == String {
    func lowercased() -> String {
        self.joined(separator: ",").lowercased()
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct AICoachGlassBackground: ViewModifier {
    private let tint = Color(red: 0.45, green: 0.40, blue: 0.98)
    private let accent = Color(red: 0.62, green: 0.40, blue: 1.00)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.55), tint.opacity(0.30), .clear],
                                center: UnitPoint(x: 0.3, y: 0.3),
                                startRadius: 4,
                                endRadius: 38
                            )
                        )
                )
                .glassEffect(.regular.tint(tint.opacity(0.55)).interactive(), in: .circle)
                .shadow(color: tint.opacity(0.45), radius: 18, y: 8)
                .shadow(color: .black.opacity(0.20), radius: 5, y: 2)
        } else {
            content
                .background(
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tint, accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(0.55)
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white.opacity(0.35), .clear],
                                    center: UnitPoint(x: 0.3, y: 0.3),
                                    startRadius: 2,
                                    endRadius: 30
                                )
                            )
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.75
                            )
                    }
                )
                .clipShape(Circle())
                .shadow(color: tint.opacity(0.45), radius: 16, y: 7)
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
        }
    }
}

/// Tinted Liquid Glass capsule for the Quick Start secondary CTAs.
/// On iOS 26 uses the real `glassEffect` material; falls back to a
/// `.ultraThinMaterial` look on older OSes so the layout is identical.
private struct QuickStartGlass: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: .rect(cornerRadius: 16))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 0.75)
                )
        }
    }
}

/// Liquid Glass surface for hub empty states. Tinted to whatever the
/// section's accent is (indigo for templates, etc.) so the empty state
/// matches the rest of the polished cards.
private struct EmptyStateGlass: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: .rect(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [tint.opacity(0.25), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.12), tint.opacity(0.04), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [tint.opacity(0.18), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }
}

/// Liquid Glass row for the Coming Soon teaser. Same tint as the
/// feature's accent so the row reads as a related-but-locked surface.
private struct ComingSoonRowGlass: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.20), lineWidth: 0.6)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.10), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.16), lineWidth: 0.6)
                )
        }
    }
}

/// Glass capsule for the nav bar Calendar + History pill. Picks up the
/// real iOS 26 material when available; falls back to a thin material
/// capsule on older OSes so the layout stays identical.
private struct ToolbarPillGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}

/// Liquid Glass treatment for the Today hero card. Tints the material
/// with the workout accent (or green when a session is in progress) so
/// the card visually responds to state. Falls back to a thin material
/// + tinted overlay on older OSes.
private struct TodayHeroGlass: ViewModifier {
    let accent: Color
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(accent.opacity(isActive ? 0.22 : 0.14)).interactive(),
                    in: .rect(cornerRadius: 20)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [accent.opacity(isActive ? 0.45 : 0.25), accent.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isActive ? 1.2 : 0.75
                        )
                )
                .shadow(color: accent.opacity(isActive ? 0.25 : 0.10), radius: 18, y: 8)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(isActive ? 0.18 : 0.10), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(accent.opacity(isActive ? 0.30 : 0.14), lineWidth: isActive ? 1.2 : 0.75)
                )
        }
    }
}

/// Liquid Glass for the "Your plan based on" summary card. Tinted cyan
/// to mirror the brain icon, identical layout on older OSes.
private struct PlanSummaryGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Color.cyan.opacity(0.10)).interactive(), in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.18), lineWidth: 0.6)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.cyan.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.12), lineWidth: 0.6)
                )
        }
    }
}

/// Liquid Glass card surface used for template / routine rows in the
/// hub. iOS 26 picks up real material; older builds get a subtle
/// indigo-tinted material that matches the rest of the section.
private struct RoutineCardGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Color.indigo.opacity(0.10)).interactive(), in: .rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.indigo.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.08), Color.purple.opacity(0.04), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.indigo.opacity(0.16), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        }
    }
}

/// Identifiable wrapper so `WeightOCRService.Result` can drive a sheet.
private struct HubPhotoResult: Identifiable {
    let id = UUID()
    let value: WeightOCRService.Result
}

/// Identifiable wrapper used to drive the per-exercise chart sheet
/// from the PowerUserInsightsSection's "Next PR" card tap.
private struct InsightExercise: Identifiable {
    var id: String { name }
    let name: String
}
