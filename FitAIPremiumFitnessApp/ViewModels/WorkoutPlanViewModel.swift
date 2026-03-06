import SwiftUI

@Observable
class WorkoutPlanViewModel {
    var aiPlan: [WorkoutDayData]? = nil
    var isGenerating: Bool = false
    var errorMessage: String? = nil
    var lastGeneratedDate: Date? = nil

    private let service = WorkoutPlanService()
    private let cacheKey = "cachedAIPlan"
    private let cacheDateKey = "cachedAIPlanDate"

    init() {
        loadCachedPlan()
    }

    var hasValidCache: Bool {
        guard let date = lastGeneratedDate else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    func generatePlan(profile: UserProfile, force: Bool = false) async {
        guard !isGenerating else { return }
        if hasValidCache && !force { return }

        isGenerating = true
        errorMessage = nil

        do {
            let plan = try await service.generateAIPlan(profile: profile)
            aiPlan = plan
            lastGeneratedDate = Date()
            savePlanToCache(plan)
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    func convertToWorkoutDays() -> [WorkoutDay] {
        guard let plan = aiPlan else { return [] }
        return plan.map { day in
            WorkoutDay(
                dayLabel: day.dayLabel,
                name: day.name,
                focusAreas: day.focusAreas,
                icon: day.icon,
                isRestDay: day.isRestDay,
                exercises: day.exercises.map { ex in
                    Exercise(
                        name: ex.name,
                        sets: ex.sets,
                        reps: ex.reps,
                        muscleGroup: ex.muscleGroup,
                        suggestedWeights: ex.suggestedWeights ?? [],
                        suggestedReps: ex.suggestedReps ?? []
                    )
                },
                isWeakPointFocus: day.isWeakPointFocus
            )
        }
    }

    private func savePlanToCache(_ plan: [WorkoutDayData]) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        }
    }

    nonisolated private func loadCachedPlan() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let plan = try? JSONDecoder().decode([WorkoutDayData].self, from: data) else {
            return
        }
        let date = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
        Task { @MainActor in
            self.aiPlan = plan
            self.lastGeneratedDate = date
        }
    }
}
