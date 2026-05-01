import Foundation

/// Greedy plate-loading calculator. Given a target weight on the bar, returns
/// the per-side plate breakdown. Pure value type — no UI.
struct PlateCalculator {
    enum Unit { case kg, lb }

    struct Result {
        /// Plate weights to load on each side, descending (e.g. [20, 10, 2.5]).
        let perSide: [Double]
        /// Weight that couldn't be expressed with available plates.
        let leftover: Double
        let bar: Double
        let unit: Unit
    }

    static let kgPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    static let lbPlates: [Double] = [45, 35, 25, 10, 5, 2.5]

    /// Default Olympic bar — 20 kg / 45 lb.
    static func defaultBar(for unit: Unit) -> Double {
        unit == .kg ? 20 : 45
    }

    /// Compute the per-side breakdown.
    static func compute(target: Double, bar: Double, unit: Unit) -> Result {
        let plates = unit == .kg ? kgPlates : lbPlates
        let totalPlateWeight = max(0, target - bar)
        let perSideTarget = totalPlateWeight / 2

        var remaining = perSideTarget
        var picked: [Double] = []
        for plate in plates {
            // Use a tolerance so 22.5 - 20 = 2.4999... still picks 2.5.
            while remaining + 0.001 >= plate {
                picked.append(plate)
                remaining -= plate
            }
        }
        return Result(perSide: picked, leftover: max(0, remaining * 2), bar: bar, unit: unit)
    }

    /// Group consecutive equal plates: [20,20,10] -> [(20,2),(10,1)].
    static func grouped(_ plates: [Double]) -> [(weight: Double, count: Int)] {
        var out: [(Double, Int)] = []
        for p in plates {
            if let last = out.last, last.0 == p {
                out[out.count - 1] = (last.0, last.1 + 1)
            } else {
                out.append((p, 1))
            }
        }
        return out.map { (weight: $0.0, count: $0.1) }
    }
}

extension PlateCalculator {
    static func isBarbellExercise(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.contains("barbell") || lower.contains("deadlift") { return true }
        if lower.contains("squat") && !lower.contains("split") && !lower.contains("pistol") && !lower.contains("jump") && !lower.contains("wall") {
            return true
        }
        if lower.contains("bench press") && !lower.contains("dumbbell") && !lower.contains("db ") {
            return true
        }
        if lower.contains("overhead press") || lower.contains("front squat") || lower.contains("hip thrust") || lower.contains("rdl") || lower.contains("romanian deadlift") {
            return !lower.contains("dumbbell") && !lower.contains("db ") && !lower.contains("single")
        }
        return false
    }
}
