import SwiftUI

struct NutritionView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = NutritionViewModel()
    @State private var showCoach: Bool = false

    private var lang: String { appState.profile.selectedLanguage }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        loadingCard
                    } else if let plan = viewModel.mealPlan {
                        macroSummaryCard(plan)
                        mealsListSection(plan)
                    } else {
                        emptyStateCard
                    }

                    if let error = viewModel.errorMessage {
                        errorCard(error)
                    }

                    quickTipsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t("nutrition", lang))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.mealPlan != nil {
                        Button(action: {
                            Task { await viewModel.generateMealPlan(profile: appState.profile, force: true) }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showCoach = true }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.35, green: 0.45, blue: 1.0), Color(red: 0.55, green: 0.35, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color(red: 0.4, green: 0.35, blue: 1.0).opacity(0.45), radius: 14, y: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $showCoach) {
                CoachView()
            }
            .task {
                await viewModel.generateMealPlan(profile: appState.profile)
            }
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Generating your meal plan...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Our AI is crafting a personalized nutrition plan based on your goals.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private func macroSummaryCard(_ plan: MealPlan) -> some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("Daily Targets")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(plan.calories) cal")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 0) {
                macroItem(value: "\(plan.protein)g", label: "Protein", color: .blue, progress: Double(plan.protein * 4) / Double(max(plan.calories, 1)))
                macroDivider
                macroItem(value: "\(plan.carbs)g", label: "Carbs", color: .green, progress: Double(plan.carbs * 4) / Double(max(plan.calories, 1)))
                macroDivider
                macroItem(value: "\(plan.fat)g", label: "Fat", color: .orange, progress: Double(plan.fat * 9) / Double(max(plan.calories, 1)))
            }

            GeometryReader { geo in
                let proteinWidth = geo.size.width * Double(plan.protein * 4) / Double(max(plan.calories, 1))
                let carbsWidth = geo.size.width * Double(plan.carbs * 4) / Double(max(plan.calories, 1))
                let fatWidth = geo.size.width - proteinWidth - carbsWidth

                HStack(spacing: 2) {
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: max(proteinWidth, 4), height: 6)
                    Capsule()
                        .fill(Color.green)
                        .frame(width: max(carbsWidth, 4), height: 6)
                    Capsule()
                        .fill(Color.orange)
                        .frame(width: max(fatWidth, 4), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.06), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }

    private func macroItem(value: String, label: String, color: Color, progress: Double) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var macroDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 40)
    }

    private func mealsListSection(_ plan: MealPlan) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text("Today's Meals")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(plan.meals.count) meals")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(Array(plan.meals.enumerated()), id: \.offset) { index, meal in
                mealRow(meal, index: index)
            }
        }
    }

    private func mealRow(_ meal: Meal, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(mealColor(index).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: meal.icon ?? "fork.knife")
                    .font(.system(size: 18))
                    .foregroundStyle(mealColor(index))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(meal.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(meal.time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(.capsule)
                }
                Text(meal.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(meal.calories)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if meal.protein > 0 {
                    Text("\(meal.protein)g P")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var emptyStateCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green.opacity(0.5))

            VStack(spacing: 6) {
                Text("AI Nutrition Plan")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Get a personalized daily meal plan based on your fitness goals, body stats, and training schedule.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Task { await viewModel.generateMealPlan(profile: appState.profile, force: true) }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Generate Meal Plan")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 14))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isLoading)
        }
        .padding(28)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button(action: { viewModel.errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var quickTipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.yellow)
                Text("Nutrition Tips")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                tipItem("Eat protein within 30 min after training")
                tipItem("Drink at least 2-3L of water daily")
                tipItem("Prioritize whole foods over supplements")
                tipItem("Spread protein intake across all meals")
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 16))
    }

    private func tipItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.green.opacity(0.4))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func mealColor(_ index: Int) -> Color {
        let colors: [Color] = [.orange, .blue, .green, .purple, .cyan]
        return colors[index % colors.count]
    }
}
