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
        lines.append("Bodyweight for BW exercises: \(weightKg)kg / \(weightLbs)lbs (used automatically for push-ups, pull-ups, dips, etc.)")

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
        if let days = profile.preferredTrainingDays, !days.isEmpty {
            lines.append("Preferred training days: \(days.joined(separator: ", "))")
        }
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

    /// Gender-aware emphasis block. Tells the model what the user actually
    /// cares about, since scoring framework, language, and exercise priority
    /// differ meaningfully between typical male and female fitness goals.
    /// Returns empty string for unspecified / non-binary profiles so the rest
    /// of the prompt remains neutral.
    static func genderEmphasis(for profile: UserProfile) -> String {
        let g = profile.gender.lowercased()
        let isFemale = g.contains("female") || g == "woman" || g == "f"
        let isMale = !isFemale && (g.contains("male") || g == "man" || g == "m")

        if isFemale {
            return """

            GENDER-SPECIFIC FOCUS (this user is female):
            Most female users prioritize lower body and posterior chain over upper-body mass. Treat their physique with that lens.
            Weight your scoring, language, and recommendations toward:
              - Glutes (highest priority): shape, fullness, lift, separation from hamstrings.
              - Hamstrings and quads: tone and shape, not mass for its own sake.
              - Core / waist: definition, low body fat, hip-to-waist ratio.
              - Posterior chain and posture: upper-back, rear delts, scapular position.
              - Arms and shoulders: toned and defined, not bulky.
            Score "legs" as a holistic lower-body assessment that explicitly INCLUDES glutes and hamstrings. Comment on glute development inside the legs/strongPoints/weakPoints text.
            De-emphasize chest mass and biceps mass unless the user explicitly listed them in their goals.
            Avoid male-coded framing: do not use "V-taper", "wide shoulders", "thick chest", "frame width" as positive descriptors. Frame proportions around hip-to-waist ratio, glute-to-waist ratio, and overall lower-body shape.
            """
        }

        if isMale {
            return """

            GENDER-SPECIFIC FOCUS (this user is male):
            Most male users prioritize upper-body mass, V-taper, and overall size. Treat their physique with that lens.
            Weight your scoring, language, and recommendations toward:
              - Chest, shoulders, back width: V-taper proportions.
              - Arms: visible size and definition (biceps, triceps).
              - Core: visible abs, low body fat.
              - Legs: proportional development to avoid upper-body-only physique.
            Frame discussion around mass, definition, and shoulder-to-waist ratio.
            """
        }

        return ""
    }

    /// Returns a system-prompt instruction telling the model to respond in the
    /// user's selected language. English profiles return an empty string so the
    /// existing prompts stay unchanged.
    ///
    /// Pass `keepExercisesEnglish=true` for endpoints whose JSON output is
    /// matched against our local exercise database (workout plans). In that
    /// mode, exercise/muscle-group identifiers stay English while user-visible
    /// fields still get translated.
    static func languageInstruction(for profile: UserProfile, keepExercisesEnglish: Bool = false) -> String {
        let lang = profile.selectedLanguage
        guard !lang.isEmpty, lang != "English" else { return "" }

        if keepExercisesEnglish {
            return """

            LANGUAGE (mandatory):
            Respond in \(lang). Translate all user-visible text fields (workout names, focus areas, descriptions, summaries, recommendations) into \(lang).
            EXCEPTION (KEEP IN ENGLISH for matching against our local database):
              - "name" of each exercise (e.g. "Bench Press", "Lat Pulldown")
              - "muscleGroup" identifier (e.g. "Chest", "Back", "Legs")
            All other text must be in \(lang).
            """
        }

        return """

        LANGUAGE (mandatory):
        Respond entirely in \(lang). Every text field, summary, recommendation, and bullet point must be in \(lang). Do not mix languages.
        """
    }
}
