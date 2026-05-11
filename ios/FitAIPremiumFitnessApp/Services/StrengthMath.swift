import Foundation

/// One place for all the strength-coach math we surface across the app:
/// estimated 1-rep max, working-weight inverse, target-weight calculators.
/// Kept stateless so it's safe to call from any thread without isolation.
enum StrengthMath {

    /// Epley estimate: 1RM = w * (1 + reps/30). Most-cited formula in the
    /// field; accurate for 1-10 reps. Returns the raw weight when reps == 1
    /// so a true single doesn't get inflated.
    static func epley1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Brzycki estimate: 1RM = w * 36 / (37 - reps). Slightly more
    /// conservative for high reps, undefined at reps >= 37.
    static func brzycki1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0, reps < 37 else { return 0 }
        if reps == 1 { return weight }
        return weight * 36.0 / (37.0 - Double(reps))
    }

    /// Default estimator app-wide. Epley is what Hevy / Strong / Jefit
    /// surface; we follow suit so cross-app comparisons line up.
    static func estimatedOneRM(weight: Double, reps: Int) -> Double {
        epley1RM(weight: weight, reps: reps)
    }

    /// Inverse Epley: given a 1RM and a target rep count, what working
    /// weight should the lifter use? Powers the warmup-set calculator
    /// and the auto-bump suggestion.
    static func weightAt(oneRM: Double, reps: Int) -> Double {
        guard oneRM > 0, reps > 0 else { return 0 }
        if reps == 1 { return oneRM }
        return oneRM / (1.0 + Double(reps) / 30.0)
    }

    /// Standard percentage-based warmup set scheme. Returns ordered
    /// (percent, reps) pairs starting from the empty bar / lightest set
    /// and stepping up to the working weight. Three-step is what most
    /// programming guides recommend for compound lifts; for isolation
    /// the lifter typically only uses the last one or two.
    static func defaultWarmupScheme() -> [(percent: Double, reps: Int)] {
        [
            (0.40, 8),
            (0.60, 5),
            (0.80, 3)
        ]
    }

    /// Warmup set weights for a given working weight, rounded to the
    /// nearest 5 (lbs) or 2.5 (kg) so they actually plate-load cleanly.
    static func warmupSets(workingWeight: Double, isMetric: Bool) -> [(weight: Double, reps: Int, percent: Double)] {
        guard workingWeight > 0 else { return [] }
        return defaultWarmupScheme().map { step in
            let raw = workingWeight * step.percent
            let rounded = roundToPlateIncrement(raw, isMetric: isMetric)
            return (rounded, step.reps, step.percent)
        }
    }

    /// Round a target weight to the nearest cleanly-loadable value.
    /// Imperial gyms standardize on 2.5 lb plate pairs (5 lb increments
    /// on the bar); metric gyms typically have 1.25 kg plate pairs (2.5
    /// kg increments on the bar).
    static func roundToPlateIncrement(_ weight: Double, isMetric: Bool) -> Double {
        let step = isMetric ? 2.5 : 5.0
        return (weight / step).rounded() * step
    }
}
