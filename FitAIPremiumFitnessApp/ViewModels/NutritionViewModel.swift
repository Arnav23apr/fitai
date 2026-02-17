import SwiftUI

@Observable
class NutritionViewModel {
    var mealPlan: MealPlan? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let service = NutritionService()
    private let cacheKey = "cachedMealPlan"
    private let cacheDateKey = "cachedMealPlanDate"

    init() {
        loadCachedPlan()
    }

    var hasValidCache: Bool {
        guard let dateData = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else { return false }
        return Calendar.current.isDateInToday(dateData)
    }

    func generateMealPlan(profile: UserProfile, force: Bool = false) async {
        guard !isLoading else { return }
        if hasValidCache && !force && mealPlan != nil { return }

        isLoading = true
        errorMessage = nil

        do {
            let plan = try await service.generateMealPlan(profile: profile)
            mealPlan = plan
            savePlanToCache(plan)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func savePlanToCache(_ plan: MealPlan) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        }
    }

    nonisolated private func loadCachedPlan() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let plan = try? JSONDecoder().decode(MealPlan.self, from: data) else {
            return
        }
        Task { @MainActor in
            self.mealPlan = plan
        }
    }
}
