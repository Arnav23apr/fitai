import Foundation
import Testing
@testable import FitAI

struct RemoteModelContractTests {

    @Test("RemoteUserProfile decodes snake_case Supabase payload and maps to UserProfile")
    func remoteUserProfileMapping() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Arnav",
          "username": "arnav",
          "email": "arnav@example.com",
          "bio": "Training hard",
          "avatar_system_name": "flame.fill",
          "gender": "male",
          "date_of_birth": "2000-01-02T03:04:05Z",
          "height_cm": 180.5,
          "weight_kg": 82.25,
          "uses_metric": true,
          "selected_language": "English",
          "force_dark_mode": true,
          "workouts_per_week": 5,
          "training_experience": "Advanced",
          "training_location": "Gym",
          "training_confidence": 8,
          "primary_goal": "Build Muscle",
          "holding_back": ["Time"],
          "goals": ["Strength"],
          "referral_code": "ABC123",
          "referred_by_code": "XYZ789",
          "friends_referred_count": 4,
          "privacy_mode": "friends_only",
          "allow_username_search": false,
          "username_changed_at": "2026-01-02T03:04:05Z",
          "is_premium": true,
          "spin_discount": 85,
          "free_scans_earned": 2,
          "total_scans": 3,
          "total_workouts": 12,
          "current_streak": 4,
          "points": 900,
          "tier": "Chadlite",
          "latest_score": 7.2,
          "last_scan_date": "2026-02-03T04:05:06Z",
          "weak_points": ["Legs"],
          "strong_points": ["Chest"],
          "completed_days_this_week": ["MON", "WED"],
          "week_start_date": "2026-02-01T00:00:00Z",
          "has_completed_onboarding": true,
          "goal_projection_url": "https://example.com/projection.jpg",
          "goal_projection_generated_at": "2026-02-04T05:06:07Z"
        }
        """.data(using: .utf8)!

        let remote = try JSONDecoder().decode(RemoteUserProfile.self, from: json)
        let profile = remote.toUserProfile()

        #expect(remote.hasCompletedOnboarding)
        #expect(profile.name == "Arnav")
        #expect(profile.username == "arnav")
        #expect(profile.email == "arnav@example.com")
        #expect(profile.avatarSystemName == "flame.fill")
        #expect(profile.heightCm == 180.5)
        #expect(profile.weightKg == 82.25)
        #expect(profile.usesMetric)
        #expect(profile.forceDarkMode)
        #expect(profile.workoutsPerWeek == 5)
        #expect(profile.trainingConfidence == 8)
        #expect(profile.referredByCode == "XYZ789")
        #expect(profile.friendsReferredCount == 4)
        #expect(profile.privacyMode == "friends_only")
        #expect(!profile.allowUsernameSearch)
        #expect(profile.isPremium)
        #expect(profile.spinDiscount == 85)
        #expect(profile.freeScansEarned == 2)
        #expect(profile.totalScans == 3)
        #expect(profile.totalWorkouts == 12)
        #expect(profile.currentStreak == 4)
        #expect(profile.points == 900)
        #expect(profile.tier == "Chadlite")
        #expect(profile.latestScore == 7.2)
        #expect(profile.weakPoints == ["Legs"])
        #expect(profile.strongPoints == ["Chest"])
        #expect(profile.completedDaysThisWeek == ["MON", "WED"])
        #expect(profile.goalProjectionURL == "https://example.com/projection.jpg")
        #expect(profile.dateOfBirth != nil)
        #expect(profile.usernameChangedAt != nil)
        #expect(profile.lastScanDate != nil)
        #expect(profile.weekStartDate != nil)
        #expect(profile.goalProjectionGeneratedAt != nil)
    }

    @Test("RemoteUserProfile optional social fields default safely")
    func remoteUserProfileOptionalDefaults() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "",
          "username": "",
          "email": "",
          "bio": "",
          "avatar_system_name": "person.crop.circle.fill",
          "gender": "",
          "date_of_birth": null,
          "height_cm": 175,
          "weight_kg": 75,
          "uses_metric": false,
          "selected_language": "English",
          "force_dark_mode": false,
          "workouts_per_week": 3,
          "training_experience": "",
          "training_location": "",
          "training_confidence": 5,
          "primary_goal": "",
          "holding_back": [],
          "goals": [],
          "referral_code": "",
          "referred_by_code": null,
          "friends_referred_count": null,
          "privacy_mode": null,
          "allow_username_search": null,
          "username_changed_at": null,
          "is_premium": false,
          "spin_discount": null,
          "free_scans_earned": 0,
          "total_scans": 0,
          "total_workouts": 0,
          "current_streak": 0,
          "points": 0,
          "tier": "Bronze",
          "latest_score": null,
          "last_scan_date": null,
          "weak_points": [],
          "strong_points": [],
          "completed_days_this_week": [],
          "week_start_date": null,
          "has_completed_onboarding": false,
          "goal_projection_url": null,
          "goal_projection_generated_at": null
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(RemoteUserProfile.self, from: json).toUserProfile()

        #expect(profile.referredByCode == "")
        #expect(profile.friendsReferredCount == 0)
        #expect(profile.privacyMode == "public")
        #expect(profile.allowUsernameSearch)
        #expect(profile.usernameChangedAt == nil)
    }

    @Test("RemoteScanEntry decodes muscle scores and rejects invalid dates")
    func remoteScanEntryMapping() throws {
        let validJSON = """
        {
          "id": "scan-1",
          "date": "2026-02-03T04:05:06Z",
          "overall_score": 7.4,
          "potential_rating": 8.8,
          "muscle_mass_rating": "Athletic",
          "strong_points": ["Chest"],
          "weak_points": ["Legs"],
          "summary": "Good progress",
          "recommendations": ["Train legs twice weekly"],
          "muscle_scores": {
            "chest": 8,
            "shoulders": 7,
            "back": 6,
            "arms": 7.5,
            "legs": 5,
            "core": 6.5,
            "glutes": 4.5
          }
        }
        """

        let entry = try #require(try JSONDecoder().decode(RemoteScanEntry.self, from: Data(validJSON.utf8)).toScanHistoryEntry())
        #expect(entry.id == "scan-1")
        #expect(entry.overallScore == 7.4)
        #expect(entry.muscleScores.chest == 8)
        #expect(entry.muscleScores.glutes == 4.5)

        let invalidDate = validJSON.replacingOccurrences(
            of: "2026-02-03T04:05:06Z",
            with: "not-a-date"
        )
        #expect(try JSONDecoder().decode(RemoteScanEntry.self, from: Data(invalidDate.utf8)).toScanHistoryEntry() == nil)
    }

    @Test("RemoteWorkoutLog decodes snake_case payload and rejects invalid dates")
    func remoteWorkoutLogMapping() throws {
        let validJSON = """
        {
          "id": "workout-1",
          "date": "2026-02-03T04:05:06Z",
          "day_name": "Push Day",
          "exercises_completed": 5,
          "total_exercises": 6,
          "duration_minutes": 47,
          "completed_exercise_names": ["Bench Press", "Overhead Press"]
        }
        """

        let log = try #require(try JSONDecoder().decode(RemoteWorkoutLog.self, from: Data(validJSON.utf8)).toWorkoutLog())
        #expect(log.id == "workout-1")
        #expect(log.dayName == "Push Day")
        #expect(log.exercisesCompleted == 5)
        #expect(log.totalExercises == 6)
        #expect(log.durationMinutes == 47)
        #expect(log.completedExerciseNames == ["Bench Press", "Overhead Press"])

        let invalidDate = validJSON.replacingOccurrences(
            of: "2026-02-03T04:05:06Z",
            with: "not-a-date"
        )
        #expect(try JSONDecoder().decode(RemoteWorkoutLog.self, from: Data(invalidDate.utf8)).toWorkoutLog() == nil)
    }
}
