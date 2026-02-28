import Foundation

struct ProfileContextBuilder {
    static func buildContext(from profile: UserProfile) -> String {
        var lines: [String] = []

        if !profile.name.isEmpty {
            lines.append("Name: \(profile.name)")
        }
        if !profile.gender.isEmpty {
            lines.append("Gender: \(profile.gender)")
        }
        if let dob = profile.dateOfBirth {
            let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            lines.append("Age: \(age) years old")
        }

        let heightCm = Int(profile.heightCm)
        let weightKg = Int(profile.weightKg)
        let heightFt = Int(profile.heightCm / 30.48)
        let heightIn = Int((profile.heightCm / 2.54).truncatingRemainder(dividingBy: 12))
        let weightLbs = Int(profile.weightKg * 2.205)
        lines.append("Height: \(heightFt)'\(heightIn)\" (\(heightCm)cm)")
        lines.append("Weight: \(weightLbs)lbs (\(weightKg)kg)")

        if !profile.primaryGoal.isEmpty {
            lines.append("Primary goal: \(profile.primaryGoal)")
        }
        if !profile.goals.isEmpty {
            lines.append("90-day goals: \(profile.goals.joined(separator: ", "))")
        }
        if !profile.trainingExperience.isEmpty {
            lines.append("Training experience: \(profile.trainingExperience)")
        }
        if !profile.trainingLocation.isEmpty {
            lines.append("Training location: \(profile.trainingLocation)")
        }
        lines.append("Workouts per week: \(profile.workoutsPerWeek)")
        lines.append("Training confidence: \(profile.trainingConfidence)/10")

        if !profile.holdingBack.isEmpty {
            lines.append("Challenges/obstacles: \(profile.holdingBack.joined(separator: ", "))")
        }
        if !profile.weakPoints.isEmpty {
            lines.append("Weak points to improve: \(profile.weakPoints.joined(separator: ", "))")
        }
        if !profile.strongPoints.isEmpty {
            lines.append("Strong points: \(profile.strongPoints.joined(separator: ", "))")
        }
        if let score = profile.latestScore {
            lines.append("Latest physique score: \(String(format: "%.1f", score))/10")
        }
        if profile.totalWorkouts > 0 {
            lines.append("Total workouts completed: \(profile.totalWorkouts)")
        }
        if profile.currentStreak > 0 {
            lines.append("Current workout streak: \(profile.currentStreak) days")
        }

        return lines.joined(separator: "\n")
    }
}
