import Testing
@testable import FitAI

struct PlateCalculatorTests {

    // MARK: - compute

    @Test("Just-the-bar target returns no plates")
    func justTheBar() {
        let r = PlateCalculator.compute(target: 20, bar: 20, unit: .kg)
        #expect(r.perSide.isEmpty)
        #expect(r.leftover == 0)
    }

    @Test("Target below bar weight has no plates and zero leftover")
    func belowBar() {
        let r = PlateCalculator.compute(target: 10, bar: 20, unit: .kg)
        #expect(r.perSide.isEmpty)
        #expect(r.leftover == 0)
    }

    @Test("100kg on 20kg bar = 25+15 per side (greedy largest-first)")
    func standard100kg() {
        let r = PlateCalculator.compute(target: 100, bar: 20, unit: .kg)
        #expect(r.perSide == [25, 15])
        #expect(r.leftover == 0)
        #expect(r.perSide.reduce(0, +) * 2 + 20 == 100)
    }

    @Test("102.5kg on 20kg bar = 25+15+1.25 per side")
    func fractional102_5() {
        let r = PlateCalculator.compute(target: 102.5, bar: 20, unit: .kg)
        #expect(r.perSide == [25, 15, 1.25])
        #expect(abs(r.leftover) < 0.01)
    }

    @Test("225 lb on 45 lb bar = 2x45 per side")
    func standard225lb() {
        let r = PlateCalculator.compute(target: 225, bar: 45, unit: .lb)
        #expect(r.perSide == [45, 45])
        #expect(r.leftover == 0)
    }

    @Test("315 lb on 45 lb bar = 3x45 per side")
    func threePlateLb() {
        let r = PlateCalculator.compute(target: 315, bar: 45, unit: .lb)
        #expect(r.perSide == [45, 45, 45])
        #expect(r.leftover == 0)
    }

    @Test("Inexpressible target reports leftover")
    func leftoverOnInexpressible() {
        // 22 kg on a 20 kg bar = 1 kg per side, no 1 kg plate exists in kgPlates
        let r = PlateCalculator.compute(target: 22, bar: 20, unit: .kg)
        #expect(r.perSide.isEmpty || r.perSide.allSatisfy { $0 >= 1.25 })
        #expect(r.leftover > 0)
    }

    @Test("Default bar weights")
    func defaultBars() {
        #expect(PlateCalculator.defaultBar(for: .kg) == 20)
        #expect(PlateCalculator.defaultBar(for: .lb) == 45)
    }

    // MARK: - grouped

    @Test("grouped collapses consecutive equal plates")
    func groupedCollapses() {
        let g = PlateCalculator.grouped([20, 20, 10, 5, 5, 5])
        #expect(g.count == 3)
        #expect(g[0].weight == 20 && g[0].count == 2)
        #expect(g[1].weight == 10 && g[1].count == 1)
        #expect(g[2].weight == 5 && g[2].count == 3)
    }

    @Test("grouped on empty input returns empty")
    func groupedEmpty() {
        #expect(PlateCalculator.grouped([]).isEmpty)
    }

    // MARK: - isBarbellExercise

    @Test("Recognizes obvious barbell movements")
    func barbellPositive() {
        #expect(PlateCalculator.isBarbellExercise("Barbell Bench Press"))
        #expect(PlateCalculator.isBarbellExercise("Barbell Squat"))
        #expect(PlateCalculator.isBarbellExercise("Romanian Deadlift"))
        #expect(PlateCalculator.isBarbellExercise("Deadlift"))
        #expect(PlateCalculator.isBarbellExercise("Front Squats"))
        #expect(PlateCalculator.isBarbellExercise("Overhead Press"))
        #expect(PlateCalculator.isBarbellExercise("Hip Thrusts"))
    }

    @Test("Excludes dumbbell / bodyweight / accessory")
    func barbellNegative() {
        #expect(!PlateCalculator.isBarbellExercise("Dumbbell Bench Press"))
        #expect(!PlateCalculator.isBarbellExercise("Dumbbell Shoulder Press"))
        #expect(!PlateCalculator.isBarbellExercise("Pull-Ups"))
        #expect(!PlateCalculator.isBarbellExercise("Push-Ups"))
        #expect(!PlateCalculator.isBarbellExercise("Lateral Raises"))
        #expect(!PlateCalculator.isBarbellExercise("Hammer Curls"))
        #expect(!PlateCalculator.isBarbellExercise("Cable Flyes"))
    }

    @Test("Excludes split / pistol / jump / wall squats")
    func barbellExcludesSquatVariants() {
        #expect(!PlateCalculator.isBarbellExercise("Bulgarian Split Squats"))
        #expect(!PlateCalculator.isBarbellExercise("Pistol Squat Progression"))
        #expect(!PlateCalculator.isBarbellExercise("Jump Squats"))
        #expect(!PlateCalculator.isBarbellExercise("Wall Sit"))
    }

    @Test("Excludes single-leg RDL")
    func excludesSingleLegRDL() {
        #expect(!PlateCalculator.isBarbellExercise("Single Leg RDL"))
    }
}
