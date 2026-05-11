import Foundation

/// Static lookup that converts a 0-10 physique score into a percentile
/// claim ("top 18% of 24-year-old males"). For v1 we use a hand-tuned
/// distribution skewed to the median user (most score 4-6). When we have
/// real cohort data from FitAI users post-launch this gets replaced with
/// a server-driven version that takes age, gender, and training years
/// into account.
///
/// Distribution targets (rough, based on general fitness research):
///   1.0 → bottom 1%
///   3.0 → ~10th percentile
///   4.0 → ~25th
///   5.0 → ~50th (median)
///   6.0 → ~75th
///   7.0 → ~90th
///   8.0 → ~97th
///   9.0 → ~99.5th
///   10.0 → top 0.1%
nonisolated enum PercentileBenchmark: Sendable {

    /// Return the percentile (0-100) for a 0-10 score. Higher = better.
    static func percentile(for score: Double) -> Int {
        let clamped = max(0.0, min(10.0, score))
        // Anchor table — interpolated between these points.
        let anchors: [(score: Double, pct: Double)] = [
            (0.0, 0.5),
            (1.0, 1.0),
            (2.0, 5.0),
            (3.0, 10.0),
            (4.0, 25.0),
            (5.0, 50.0),
            (6.0, 75.0),
            (7.0, 90.0),
            (8.0, 97.0),
            (9.0, 99.5),
            (10.0, 99.9),
        ]
        // Linear interpolation between anchors.
        for i in 0..<(anchors.count - 1) {
            let lo = anchors[i]
            let hi = anchors[i + 1]
            if clamped >= lo.score && clamped <= hi.score {
                let t = (clamped - lo.score) / (hi.score - lo.score)
                let p = lo.pct + (hi.pct - lo.pct) * t
                return Int(p.rounded())
            }
        }
        return Int(clamped * 10)
    }

    /// "Top X%" formulation. Beats 87% of users → top 13%.
    static func topPercent(for score: Double) -> Int {
        let pct = percentile(for: score)
        return max(1, 100 - pct)
    }

    /// Build a human-readable claim line. Defaults to "users" cohort
    /// when age or gender aren't usable, otherwise tailors the line.
    /// Example: "top 13% of 24-year-old males"
    static func claim(score: Double, gender: String, dateOfBirth: Date?) -> String {
        let topPct = topPercent(for: score)
        let g = gender.lowercased()
        let isFemale = g.contains("female") || g == "woman" || g == "f"
        let isMale = !isFemale && (g.contains("male") || g == "man" || g == "m")

        let cohort: String
        if let dob = dateOfBirth, let age = ageFrom(dob: dob), age >= 13 && age <= 80 {
            if isMale       { cohort = "\(age)-year-old males" }
            else if isFemale { cohort = "\(age)-year-old females" }
            else             { cohort = "users your age" }
        } else if isMale {
            cohort = "men"
        } else if isFemale {
            cohort = "women"
        } else {
            cohort = "users"
        }
        return "top \(topPct)% of \(cohort)"
    }

    private static func ageFrom(dob: Date) -> Int? {
        let comps = Calendar.current.dateComponents([.year], from: dob, to: Date())
        return comps.year
    }
}
