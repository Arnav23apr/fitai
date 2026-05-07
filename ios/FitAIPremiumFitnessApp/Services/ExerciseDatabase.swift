import Foundation

final class ExerciseDatabase: Sendable {
    static let shared = ExerciseDatabase()

    private let exercises: [String: ExerciseDemoInfo]
    private let media: [String: ExerciseMediaEntry]

    private init() {
        self.media = ExerciseDatabase.loadMediaManifest()
        var db: [String: ExerciseDemoInfo] = [:]

        // MARK: - Push Exercises

        db["Barbell Bench Press"] = ExerciseDemoInfo(
            name: "Barbell Bench Press",
            instructions: [
                "Lie flat on a bench with eyes under the bar.",
                "Grip the bar slightly wider than shoulder width.",
                "Unrack and lower the bar to your mid-chest.",
                "Press the bar up until arms are fully extended.",
                "Keep your feet flat and shoulder blades pinched."
            ],
            tips: [
                "Drive through your feet for leg drive.",
                "Keep wrists straight, bar over forearms.",
                "Don't bounce the bar off your chest."
            ],
            primaryMuscles: ["Chest"],
            secondaryMuscles: ["Triceps", "Front Delts"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Incline Dumbbell Press"] = ExerciseDemoInfo(
            name: "Incline Dumbbell Press",
            instructions: [
                "Set bench to 30-45 degree incline.",
                "Hold dumbbells at shoulder height, palms forward.",
                "Press dumbbells up and slightly inward.",
                "Lower with control until elbows are at 90 degrees.",
                "Squeeze chest at the top of each rep."
            ],
            tips: [
                "Don't flare elbows past 75 degrees.",
                "Keep a slight arch in your lower back.",
                "Focus on the upper chest squeeze."
            ],
            primaryMuscles: ["Upper Chest"],
            secondaryMuscles: ["Shoulders", "Triceps"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Overhead Press"] = ExerciseDemoInfo(
            name: "Overhead Press",
            instructions: [
                "Stand with feet shoulder-width apart.",
                "Hold the bar at shoulder height, grip just outside shoulders.",
                "Press the bar overhead, moving your head forward as it passes.",
                "Lock out arms fully at the top.",
                "Lower with control back to shoulders."
            ],
            tips: [
                "Brace your core throughout the movement.",
                "Don't lean back excessively.",
                "Squeeze glutes for stability."
            ],
            primaryMuscles: ["Shoulders"],
            secondaryMuscles: ["Triceps", "Upper Chest"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Lateral Raises"] = ExerciseDemoInfo(
            name: "Lateral Raises",
            instructions: [
                "Stand with dumbbells at your sides.",
                "Raise arms out to the sides until parallel with the floor.",
                "Lead with your elbows, slight bend in arms.",
                "Lower slowly with control.",
                "Keep a slight forward lean."
            ],
            tips: [
                "Don't swing or use momentum.",
                "Think about pouring water from a pitcher.",
                "Lighter weight with strict form beats heavy swinging."
            ],
            primaryMuscles: ["Side Delts"],
            secondaryMuscles: ["Traps"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Cable Flyes"] = ExerciseDemoInfo(
            name: "Cable Flyes",
            instructions: [
                "Set cables to shoulder height.",
                "Step forward into a split stance.",
                "With slight elbow bend, bring handles together in front.",
                "Squeeze chest at the peak contraction.",
                "Return slowly to the starting position."
            ],
            tips: [
                "Focus on the chest squeeze, not the arms.",
                "Keep elbows at a fixed angle throughout.",
                "Control the eccentric (return) phase."
            ],
            primaryMuscles: ["Chest"],
            secondaryMuscles: ["Front Delts"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Tricep Pushdowns"] = ExerciseDemoInfo(
            name: "Tricep Pushdowns",
            instructions: [
                "Attach a straight or V-bar to a high cable.",
                "Grip the bar with palms down, elbows at your sides.",
                "Push the bar down until arms are fully extended.",
                "Squeeze triceps at the bottom.",
                "Return slowly, keeping elbows pinned."
            ],
            tips: [
                "Don't let elbows drift forward.",
                "Keep your torso upright.",
                "Use a controlled tempo, no swinging."
            ],
            primaryMuscles: ["Triceps"],
            secondaryMuscles: [],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Push-Ups"] = ExerciseDemoInfo(
            name: "Push-Ups",
            instructions: [
                "Start in a plank position, hands shoulder-width apart.",
                "Lower your body until chest nearly touches the floor.",
                "Keep your body in a straight line throughout.",
                "Push back up to the starting position.",
                "Fully extend arms at the top."
            ],
            tips: [
                "Don't let hips sag or pike up.",
                "Keep core engaged the entire time.",
                "Elbows at about 45 degrees, not flared out."
            ],
            primaryMuscles: ["Chest"],
            secondaryMuscles: ["Triceps", "Shoulders", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Pike Push-Ups"] = ExerciseDemoInfo(
            name: "Pike Push-Ups",
            instructions: [
                "Start in a downward dog position with hips high.",
                "Hands shoulder-width apart, feet hip-width.",
                "Bend elbows and lower your head toward the floor.",
                "Press back up to the starting position.",
                "Keep hips elevated throughout."
            ],
            tips: [
                "The more vertical your torso, the more shoulder focus.",
                "Elevate feet on a bench for more difficulty.",
                "Great progression toward handstand push-ups."
            ],
            primaryMuscles: ["Shoulders"],
            secondaryMuscles: ["Triceps", "Upper Chest"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Diamond Push-Ups"] = ExerciseDemoInfo(
            name: "Diamond Push-Ups",
            instructions: [
                "Place hands together under your chest, forming a diamond shape.",
                "Lower your chest to your hands.",
                "Keep elbows close to your body.",
                "Push back up to full extension.",
                "Maintain a straight body line."
            ],
            tips: [
                "If too hard, widen hand placement slightly.",
                "Focus on squeezing triceps at the top.",
                "Keep core braced throughout."
            ],
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Chest", "Shoulders"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Dips (Chair)"] = ExerciseDemoInfo(
            name: "Dips (Chair)",
            instructions: [
                "Place hands on the edge of a chair behind you.",
                "Extend legs out in front.",
                "Lower your body by bending elbows to 90 degrees.",
                "Push back up to the starting position.",
                "Keep your back close to the chair."
            ],
            tips: [
                "Bend knees to make it easier.",
                "Don't go too deep to protect shoulders.",
                "Keep shoulders down, away from ears."
            ],
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Chest", "Shoulders"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Decline Push-Ups"] = ExerciseDemoInfo(
            name: "Decline Push-Ups",
            instructions: [
                "Place feet on an elevated surface (bench or step).",
                "Hands on the floor, shoulder-width apart.",
                "Lower your chest toward the floor.",
                "Push back up to full extension.",
                "Keep body in a straight line."
            ],
            tips: [
                "Higher elevation = more upper chest/shoulder focus.",
                "Don't let your lower back sag.",
                "Great alternative to incline bench press."
            ],
            primaryMuscles: ["Upper Chest"],
            secondaryMuscles: ["Shoulders", "Triceps"],
            videoURL: "",
            thumbnailURL: ""
        )

        // MARK: - Pull Exercises

        db["Barbell Rows"] = ExerciseDemoInfo(
            name: "Barbell Rows",
            instructions: [
                "Hinge at the hips with a slight knee bend.",
                "Grip the bar slightly wider than shoulder width.",
                "Pull the bar to your lower chest/upper abs.",
                "Squeeze shoulder blades together at the top.",
                "Lower with control."
            ],
            tips: [
                "Keep your back flat, don't round.",
                "Torso angle about 45 degrees.",
                "Pull with your elbows, not your hands."
            ],
            primaryMuscles: ["Back"],
            secondaryMuscles: ["Biceps", "Rear Delts"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Lat Pulldown"] = ExerciseDemoInfo(
            name: "Lat Pulldown",
            instructions: [
                "Sit with thighs secured under the pad.",
                "Grip the bar wider than shoulder width.",
                "Pull the bar down to your upper chest.",
                "Squeeze lats at the bottom.",
                "Return slowly to full extension overhead."
            ],
            tips: [
                "Lean back slightly, don't swing.",
                "Think about driving elbows down into your pockets.",
                "Full stretch at the top of each rep."
            ],
            primaryMuscles: ["Lats"],
            secondaryMuscles: ["Biceps", "Rear Delts"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Face Pulls"] = ExerciseDemoInfo(
            name: "Face Pulls",
            instructions: [
                "Set cable at upper chest height with rope attachment.",
                "Pull the rope toward your face.",
                "Separate the ends of the rope as you pull.",
                "Externally rotate at the end position.",
                "Return slowly with control."
            ],
            tips: [
                "Squeeze shoulder blades together.",
                "Keep elbows high throughout.",
                "Use lighter weight for proper form."
            ],
            primaryMuscles: ["Rear Delts"],
            secondaryMuscles: ["Traps", "Rotator Cuff"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Seated Cable Row"] = ExerciseDemoInfo(
            name: "Seated Cable Row",
            instructions: [
                "Sit with feet on the platform, knees slightly bent.",
                "Grab the handle with arms extended.",
                "Pull the handle to your torso.",
                "Squeeze shoulder blades at peak contraction.",
                "Extend arms back slowly."
            ],
            tips: [
                "Don't lean too far forward or back.",
                "Keep chest up throughout.",
                "Focus on pulling with your back, not arms."
            ],
            primaryMuscles: ["Mid Back"],
            secondaryMuscles: ["Biceps", "Lats"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Barbell Curls"] = ExerciseDemoInfo(
            name: "Barbell Curls",
            instructions: [
                "Stand with feet shoulder-width apart.",
                "Grip the bar at shoulder width, palms up.",
                "Curl the bar up by bending at the elbows.",
                "Squeeze biceps at the top.",
                "Lower with control, fully extend arms."
            ],
            tips: [
                "Keep elbows pinned to your sides.",
                "Don't swing your body for momentum.",
                "Control the negative portion."
            ],
            primaryMuscles: ["Biceps"],
            secondaryMuscles: ["Forearms"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Hammer Curls"] = ExerciseDemoInfo(
            name: "Hammer Curls",
            instructions: [
                "Hold dumbbells with palms facing each other.",
                "Curl the weights up while keeping palms neutral.",
                "Squeeze at the top.",
                "Lower with control.",
                "Keep elbows at your sides."
            ],
            tips: [
                "Great for brachialis and forearm development.",
                "Can be done alternating or simultaneous.",
                "Avoid swinging the weights."
            ],
            primaryMuscles: ["Biceps"],
            secondaryMuscles: ["Forearms", "Brachialis"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Pull-Ups"] = ExerciseDemoInfo(
            name: "Pull-Ups",
            instructions: [
                "Hang from a bar with palms facing away, wider than shoulders.",
                "Pull yourself up until your chin clears the bar.",
                "Squeeze lats at the top.",
                "Lower with control to a dead hang.",
                "Full range of motion on every rep."
            ],
            tips: [
                "Initiate the pull by depressing your shoulder blades.",
                "Avoid kipping or swinging.",
                "Use bands for assistance if needed."
            ],
            primaryMuscles: ["Back"],
            secondaryMuscles: ["Biceps", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Inverted Rows"] = ExerciseDemoInfo(
            name: "Inverted Rows",
            instructions: [
                "Set a bar at waist height.",
                "Hang underneath with arms extended.",
                "Pull your chest to the bar.",
                "Squeeze shoulder blades together.",
                "Lower back to full extension."
            ],
            tips: [
                "Keep body in a straight line like a reverse plank.",
                "Elevate feet to increase difficulty.",
                "Great pull-up progression exercise."
            ],
            primaryMuscles: ["Mid Back"],
            secondaryMuscles: ["Biceps", "Rear Delts"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Superman Hold"] = ExerciseDemoInfo(
            name: "Superman Hold",
            instructions: [
                "Lie face down with arms extended overhead.",
                "Simultaneously lift arms, chest, and legs off the floor.",
                "Hold the top position for the prescribed time.",
                "Lower back down with control.",
                "Keep your neck in a neutral position."
            ],
            tips: [
                "Squeeze glutes at the top.",
                "Don't hyperextend your neck.",
                "Breathe normally while holding."
            ],
            primaryMuscles: ["Lower Back"],
            secondaryMuscles: ["Glutes", "Hamstrings"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Band Face Pulls"] = ExerciseDemoInfo(
            name: "Band Face Pulls",
            instructions: [
                "Anchor a resistance band at face height.",
                "Grip both ends and step back for tension.",
                "Pull the band toward your face.",
                "Separate hands and externally rotate at the end.",
                "Return slowly."
            ],
            tips: [
                "Keep elbows high.",
                "Great for shoulder health and posture.",
                "Use this as a warm-up too."
            ],
            primaryMuscles: ["Rear Delts"],
            secondaryMuscles: ["Traps", "Rotator Cuff"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Doorway Curls"] = ExerciseDemoInfo(
            name: "Doorway Curls",
            instructions: [
                "Stand in a doorway, grip the frame at waist height.",
                "Lean back with arms extended.",
                "Curl yourself toward the doorframe.",
                "Squeeze biceps at peak contraction.",
                "Lower back slowly."
            ],
            tips: [
                "Adjust foot position to change difficulty.",
                "Keep body straight like a plank.",
                "Good bodyweight bicep option at home."
            ],
            primaryMuscles: ["Biceps"],
            secondaryMuscles: ["Forearms"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Chin-Ups"] = ExerciseDemoInfo(
            name: "Chin-Ups",
            instructions: [
                "Hang from a bar with palms facing you, shoulder-width grip.",
                "Pull yourself up until chin clears the bar.",
                "Squeeze biceps and lats at the top.",
                "Lower with control to a dead hang.",
                "Full range of motion on every rep."
            ],
            tips: [
                "Slightly easier than pull-ups due to bicep involvement.",
                "Keep core tight to avoid swinging.",
                "Great for both back and bicep development."
            ],
            primaryMuscles: ["Biceps"],
            secondaryMuscles: ["Back", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        // MARK: - Leg Exercises

        db["Barbell Squat"] = ExerciseDemoInfo(
            name: "Barbell Squat",
            instructions: [
                "Place the bar on your upper traps.",
                "Stand with feet shoulder-width apart, toes slightly out.",
                "Squat down by pushing hips back and bending knees.",
                "Go until thighs are at least parallel to the floor.",
                "Drive through your feet to stand back up."
            ],
            tips: [
                "Keep your chest up and core braced.",
                "Knees should track over toes.",
                "Don't let knees cave inward."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Hamstrings", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Romanian Deadlift"] = ExerciseDemoInfo(
            name: "Romanian Deadlift",
            instructions: [
                "Hold a barbell with an overhand grip at hip height.",
                "Push hips back while lowering the bar along your legs.",
                "Keep a slight bend in your knees throughout.",
                "Lower until you feel a strong hamstring stretch.",
                "Drive hips forward to return to standing."
            ],
            tips: [
                "Keep the bar close to your body.",
                "Don't round your lower back.",
                "Feel the stretch in your hamstrings, not your back."
            ],
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Glutes", "Lower Back"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Leg Press"] = ExerciseDemoInfo(
            name: "Leg Press",
            instructions: [
                "Sit in the leg press with feet shoulder-width on the platform.",
                "Release the safety handles.",
                "Lower the platform by bending knees toward your chest.",
                "Push through your feet to extend legs.",
                "Don't fully lock out knees at the top."
            ],
            tips: [
                "Foot placement changes emphasis: high = glutes, low = quads.",
                "Keep your lower back pressed into the seat.",
                "Control the weight, don't bounce at the bottom."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Hamstrings"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Walking Lunges"] = ExerciseDemoInfo(
            name: "Walking Lunges",
            instructions: [
                "Stand tall with dumbbells at your sides.",
                "Step forward into a lunge, lowering back knee toward the floor.",
                "Front knee should be at 90 degrees.",
                "Push off the front foot to step into the next lunge.",
                "Alternate legs as you walk forward."
            ],
            tips: [
                "Keep your torso upright.",
                "Don't let the front knee go past your toes.",
                "Take controlled steps, not rushed."
            ],
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Quads", "Hamstrings"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Calf Raises"] = ExerciseDemoInfo(
            name: "Calf Raises",
            instructions: [
                "Stand on the edge of a step with heels hanging off.",
                "Rise up on your toes as high as possible.",
                "Squeeze calves at the top.",
                "Lower your heels below the step for a full stretch.",
                "Repeat with control."
            ],
            tips: [
                "Full range of motion is key for calf growth.",
                "Pause at the top for 1-2 seconds.",
                "Add weight with dumbbells as you progress."
            ],
            primaryMuscles: ["Calves"],
            secondaryMuscles: [],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Leg Curl"] = ExerciseDemoInfo(
            name: "Leg Curl",
            instructions: [
                "Lie face down on the leg curl machine.",
                "Adjust pad to rest on your lower calves.",
                "Curl the weight up by bending your knees.",
                "Squeeze hamstrings at the top.",
                "Lower slowly to the start."
            ],
            tips: [
                "Don't lift your hips off the pad.",
                "Control the weight on the way down.",
                "Try a slow negative for extra growth stimulus."
            ],
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: [],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Bulgarian Split Squats"] = ExerciseDemoInfo(
            name: "Bulgarian Split Squats",
            instructions: [
                "Stand in front of a bench, place one foot behind on the bench.",
                "Lower your body until the front thigh is parallel to the floor.",
                "Keep most of your weight on the front foot.",
                "Push through the front foot to stand back up.",
                "Complete all reps on one side, then switch."
            ],
            tips: [
                "Keep your torso upright.",
                "Front knee should track over toes.",
                "Great for fixing imbalances between legs."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Hamstrings"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Glute Bridges"] = ExerciseDemoInfo(
            name: "Glute Bridges",
            instructions: [
                "Lie on your back, knees bent, feet flat on the floor.",
                "Drive through your heels to lift hips toward the ceiling.",
                "Squeeze glutes hard at the top.",
                "Hold for a second at the top.",
                "Lower back down with control."
            ],
            tips: [
                "Don't hyperextend your lower back.",
                "Place a weight on your hips for added resistance.",
                "Keep core engaged throughout."
            ],
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Hamstrings", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Jump Squats"] = ExerciseDemoInfo(
            name: "Jump Squats",
            instructions: [
                "Stand with feet shoulder-width apart.",
                "Squat down to parallel.",
                "Explode up into a jump.",
                "Land softly by bending your knees.",
                "Immediately go into the next rep."
            ],
            tips: [
                "Land quietly — soft landing = less joint stress.",
                "Use your arms to generate momentum.",
                "Great for power development."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Calves"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Single Leg RDL"] = ExerciseDemoInfo(
            name: "Single Leg RDL",
            instructions: [
                "Stand on one leg, holding a dumbbell in the opposite hand.",
                "Hinge at the hip, extending the free leg behind you.",
                "Lower the dumbbell toward the floor.",
                "Keep your back flat and hips square.",
                "Return to standing by driving hips forward."
            ],
            tips: [
                "Focus on balance — go slower if needed.",
                "Great for hamstring flexibility and strength.",
                "Keep a micro-bend in the standing knee."
            ],
            primaryMuscles: ["Hamstrings"],
            secondaryMuscles: ["Glutes", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Wall Sit"] = ExerciseDemoInfo(
            name: "Wall Sit",
            instructions: [
                "Lean against a wall with feet shoulder-width apart.",
                "Slide down until thighs are parallel to the floor.",
                "Keep your back flat against the wall.",
                "Hold the position for the prescribed time.",
                "Keep knees at 90 degrees."
            ],
            tips: [
                "Breathe normally — don't hold your breath.",
                "Push through the challenge, it's mental too.",
                "Add a weight on your thighs for progression."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes"],
            videoURL: "",
            thumbnailURL: ""
        )

        // MARK: - Upper Body

        db["Dumbbell Bench Press"] = ExerciseDemoInfo(
            name: "Dumbbell Bench Press",
            instructions: [
                "Lie on a flat bench with a dumbbell in each hand.",
                "Hold dumbbells at chest height, palms facing forward.",
                "Press the dumbbells up and slightly inward.",
                "Touch them at the top without clanking.",
                "Lower with control until elbows are at 90 degrees."
            ],
            tips: [
                "Greater range of motion than barbell bench.",
                "Keep shoulder blades pinched together.",
                "Great for fixing strength imbalances."
            ],
            primaryMuscles: ["Chest"],
            secondaryMuscles: ["Triceps", "Shoulders"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Cable Rows"] = ExerciseDemoInfo(
            name: "Cable Rows",
            instructions: [
                "Sit at a cable row station with feet on the platform.",
                "Grip the handle with arms extended.",
                "Pull the handle to your torso.",
                "Squeeze shoulder blades at the back.",
                "Extend arms back slowly."
            ],
            tips: [
                "Keep your chest up and back straight.",
                "Pull with your elbows, not your hands.",
                "Don't lean excessively forward or backward."
            ],
            primaryMuscles: ["Back"],
            secondaryMuscles: ["Biceps", "Rear Delts"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Arnold Press"] = ExerciseDemoInfo(
            name: "Arnold Press",
            instructions: [
                "Hold dumbbells at shoulder height with palms facing you.",
                "Press up while rotating palms to face forward.",
                "Fully extend arms overhead.",
                "Reverse the rotation as you lower.",
                "Return to the starting position."
            ],
            tips: [
                "Smooth rotation — don't rush it.",
                "Hits all three delt heads in one movement.",
                "Use lighter weight than standard overhead press."
            ],
            primaryMuscles: ["Shoulders"],
            secondaryMuscles: ["Triceps", "Upper Chest"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Incline Curls"] = ExerciseDemoInfo(
            name: "Incline Curls",
            instructions: [
                "Set bench to 45-60 degree incline.",
                "Let arms hang straight down with dumbbells.",
                "Curl the weights up without moving your upper arms.",
                "Squeeze biceps at the top.",
                "Lower slowly to the starting position."
            ],
            tips: [
                "Great stretch on the long head of biceps.",
                "Don't swing or use momentum.",
                "Lighter weight works best for strict form."
            ],
            primaryMuscles: ["Biceps"],
            secondaryMuscles: [],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Overhead Tricep Extension"] = ExerciseDemoInfo(
            name: "Overhead Tricep Extension",
            instructions: [
                "Hold a dumbbell with both hands overhead.",
                "Lower the weight behind your head by bending elbows.",
                "Keep upper arms close to your ears.",
                "Extend arms back to the starting position.",
                "Squeeze triceps at the top."
            ],
            tips: [
                "Don't flare elbows out.",
                "Great for the long head of the triceps.",
                "Can also be done with a cable."
            ],
            primaryMuscles: ["Triceps"],
            secondaryMuscles: [],
            videoURL: "",
            thumbnailURL: ""
        )

        // MARK: - Lower Body / Core

        db["Front Squats"] = ExerciseDemoInfo(
            name: "Front Squats",
            instructions: [
                "Rest the bar on front delts with elbows high.",
                "Feet shoulder-width apart.",
                "Squat down, keeping torso upright.",
                "Go to at least parallel depth.",
                "Drive through your heels to stand."
            ],
            tips: [
                "Keep elbows high — don't let them drop.",
                "More quad-dominant than back squats.",
                "Cross-grip or clean grip, whichever is comfortable."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Hip Thrusts"] = ExerciseDemoInfo(
            name: "Hip Thrusts",
            instructions: [
                "Sit on the floor with upper back against a bench.",
                "Roll a barbell over your hips.",
                "Drive through your heels to thrust hips upward.",
                "Squeeze glutes hard at the top.",
                "Lower with control."
            ],
            tips: [
                "Chin should tuck as you thrust up.",
                "Don't hyperextend your back.",
                "The best exercise for glute development."
            ],
            primaryMuscles: ["Glutes"],
            secondaryMuscles: ["Hamstrings"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Leg Extensions"] = ExerciseDemoInfo(
            name: "Leg Extensions",
            instructions: [
                "Sit in the machine with back against the pad.",
                "Hook feet under the roller pad.",
                "Extend legs until straight.",
                "Squeeze quads at the top.",
                "Lower with control."
            ],
            tips: [
                "Don't use momentum or swing.",
                "Pause at the top for maximum contraction.",
                "Great as a finisher exercise."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: [],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Hanging Leg Raises"] = ExerciseDemoInfo(
            name: "Hanging Leg Raises",
            instructions: [
                "Hang from a pull-up bar with arms extended.",
                "Raise your legs until they're parallel to the floor.",
                "Keep legs straight (or bend knees to make easier).",
                "Lower with control — no swinging.",
                "Engage core throughout."
            ],
            tips: [
                "Focus on tilting your pelvis to engage lower abs.",
                "Don't swing for momentum.",
                "Bend knees if straight legs are too challenging."
            ],
            primaryMuscles: ["Core"],
            secondaryMuscles: ["Hip Flexors"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Cable Woodchops"] = ExerciseDemoInfo(
            name: "Cable Woodchops",
            instructions: [
                "Set cable to high position.",
                "Stand sideways to the machine.",
                "Pull the handle diagonally across your body.",
                "Rotate through your core, not just your arms.",
                "Return slowly to the start."
            ],
            tips: [
                "Keep arms relatively straight.",
                "Power comes from core rotation.",
                "Great for rotational strength."
            ],
            primaryMuscles: ["Obliques"],
            secondaryMuscles: ["Core", "Shoulders"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Pistol Squat Progression"] = ExerciseDemoInfo(
            name: "Pistol Squat Progression",
            instructions: [
                "Stand on one leg with the other extended in front.",
                "Lower yourself on the standing leg as deep as possible.",
                "Keep your chest up and core tight.",
                "Push through your heel to stand back up.",
                "Use a support (wall/TRX) if needed."
            ],
            tips: [
                "Start with assisted versions (holding a door frame).",
                "Ankle mobility is often the limiting factor.",
                "One of the best bodyweight leg exercises."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Plank"] = ExerciseDemoInfo(
            name: "Plank",
            instructions: [
                "Start face down, resting on forearms and toes.",
                "Keep body in a straight line from head to heels.",
                "Engage core by pulling belly button toward spine.",
                "Hold for the prescribed time.",
                "Breathe normally throughout."
            ],
            tips: [
                "Don't let hips sag or pike up.",
                "Squeeze glutes for stability.",
                "Look at the floor to keep neck neutral."
            ],
            primaryMuscles: ["Core"],
            secondaryMuscles: ["Shoulders", "Glutes"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Russian Twists"] = ExerciseDemoInfo(
            name: "Russian Twists",
            instructions: [
                "Sit with knees bent, feet off the floor.",
                "Lean back slightly, keeping back straight.",
                "Rotate your torso side to side.",
                "Touch the floor beside you on each side.",
                "Keep core engaged throughout."
            ],
            tips: [
                "Hold a weight for added difficulty.",
                "Keep feet elevated for more core engagement.",
                "Controlled rotations, don't rush."
            ],
            primaryMuscles: ["Obliques"],
            secondaryMuscles: ["Core"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Mountain Climbers"] = ExerciseDemoInfo(
            name: "Mountain Climbers",
            instructions: [
                "Start in a push-up position.",
                "Drive one knee toward your chest.",
                "Quickly switch legs in a running motion.",
                "Keep hips low and core tight.",
                "Maintain a steady pace."
            ],
            tips: [
                "Don't let hips bounce up and down.",
                "Go faster for more cardio, slower for more core.",
                "Keep shoulders over wrists."
            ],
            primaryMuscles: ["Core"],
            secondaryMuscles: ["Shoulders", "Quads"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Deadlift"] = ExerciseDemoInfo(
            name: "Deadlift",
            instructions: [
                "Stand with feet hip-width, bar over mid-foot.",
                "Hinge at the hips and grip the bar just outside your knees.",
                "Keep back flat, chest up.",
                "Drive through your heels to stand up.",
                "Lock out hips at the top."
            ],
            tips: [
                "Keep the bar close to your body throughout.",
                "Don't round your lower back.",
                "Push the floor away rather than pulling the bar up."
            ],
            primaryMuscles: ["Back", "Hamstrings"],
            secondaryMuscles: ["Glutes", "Core", "Traps"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Dumbbell Lunges"] = ExerciseDemoInfo(
            name: "Dumbbell Lunges",
            instructions: [
                "Stand with dumbbells at your sides.",
                "Step forward into a lunge position.",
                "Lower your back knee toward the floor.",
                "Push off the front foot to return to standing.",
                "Alternate legs each rep."
            ],
            tips: [
                "Keep torso upright.",
                "Front knee stays over the ankle.",
                "Step far enough forward to maintain 90-degree angles."
            ],
            primaryMuscles: ["Quads"],
            secondaryMuscles: ["Glutes", "Hamstrings"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Dumbbell Shoulder Press"] = ExerciseDemoInfo(
            name: "Dumbbell Shoulder Press",
            instructions: [
                "Hold dumbbells at shoulder height, palms forward.",
                "Press the weights overhead until arms are fully extended.",
                "Lower with control back to shoulder height.",
                "Keep core braced throughout.",
                "Don't arch your back excessively."
            ],
            tips: [
                "Allows more natural range of motion than barbell.",
                "Great for fixing strength imbalances.",
                "Keep a slight bend at the top — don't lock out aggressively."
            ],
            primaryMuscles: ["Shoulders"],
            secondaryMuscles: ["Triceps"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Tricep Dips"] = ExerciseDemoInfo(
            name: "Tricep Dips",
            instructions: [
                "Grip parallel bars and lift yourself up.",
                "Lower your body by bending elbows to 90 degrees.",
                "Keep elbows close to your body for tricep focus.",
                "Push back up to full extension.",
                "Keep your torso upright."
            ],
            tips: [
                "Leaning forward shifts focus to chest.",
                "Upright torso = more tricep.",
                "Don't go too deep to protect shoulders."
            ],
            primaryMuscles: ["Triceps"],
            secondaryMuscles: ["Chest", "Shoulders"],
            videoURL: "",
            thumbnailURL: ""
        )

        db["Leg Raises"] = ExerciseDemoInfo(
            name: "Leg Raises",
            instructions: [
                "Lie flat on your back, legs straight.",
                "Place hands under your hips for support.",
                "Raise legs to 90 degrees.",
                "Lower slowly without touching the floor.",
                "Keep lower back pressed into the ground."
            ],
            tips: [
                "If lower back lifts off, don't go as low.",
                "Bend knees slightly if hamstrings are tight.",
                "Slow and controlled beats fast and sloppy."
            ],
            primaryMuscles: ["Core"],
            secondaryMuscles: ["Hip Flexors"],
            videoURL: "",
            thumbnailURL: ""
        )

        // Merge in the bundled free-exercise-db (873 entries, MIT-licensed
        // from yuhonas/free-exercise-db). Hardcoded entries above win on
        // name collision because they carry video URLs + tips that the
        // bundled data doesn't include.
        for bundled in ExerciseDatabase.loadBundledExercises() {
            let info = bundled.toDemoInfo()
            if db[info.name] == nil {
                db[info.name] = info
            }
        }

        // Merge in wger.de exercises if the import script has been run
        // (CC-BY-SA 4.0 — attributed in Profile → About). Same precedence
        // rule as above: existing entries win on collision so we don't
        // overwrite curated tips/instructions with auto-generated ones.
        for entry in ExerciseDatabase.loadWgerExercises() {
            if db[entry.name] == nil {
                db[entry.name] = entry
            }
        }

        self.exercises = db
    }

    /// All exercise names known to the database. Used by the routine
    /// editor's exercise picker for browsing/searching the full catalog.
    var allNames: [String] {
        Array(exercises.keys).sorted()
    }

    /// Names filtered by primary muscle group (case-insensitive contains).
    /// `muscle` is one of: chest, back, shoulders, biceps, triceps, legs,
    /// quadriceps, hamstrings, glutes, calves, abdominals, forearms, traps,
    /// lats, abs, core. Pass empty string for all.
    func names(forMuscle muscle: String) -> [String] {
        guard !muscle.isEmpty else { return allNames }
        let needle = muscle.lowercased()
        return exercises
            .filter { _, info in
                info.primaryMuscles.contains { $0.lowercased().contains(needle) }
            }
            .map(\.key)
            .sorted()
    }

    /// Search by case-insensitive substring on the exercise name.
    func search(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allNames }
        return exercises.keys
            .filter { $0.lowercased().contains(q) }
            .sorted()
    }

    func info(for exerciseName: String) -> ExerciseDemoInfo {
        let base: ExerciseDemoInfo
        if let exact = exercises[exerciseName] {
            base = exact
        } else if let match = exercises.first(where: { $0.key.lowercased() == exerciseName.lowercased() })?.value {
            base = match
        } else {
            base = ExerciseDemoInfo(
                name: exerciseName,
                instructions: ["Perform the exercise with controlled form.", "Focus on the mind-muscle connection.", "Use a weight that allows proper technique."],
                tips: ["Start light and increase weight gradually.", "Rest 60-90 seconds between sets."],
                primaryMuscles: [],
                secondaryMuscles: [],
                videoURL: "",
                thumbnailURL: ""
            )
        }

        let mediaKey = exerciseName.lowercased()
        guard let entry = media[mediaKey] ?? media[base.name.lowercased()] else { return base }
        return ExerciseDemoInfo(
            name: base.name,
            instructions: base.instructions,
            tips: base.tips,
            primaryMuscles: base.primaryMuscles,
            secondaryMuscles: base.secondaryMuscles,
            videoURL: entry.video,
            thumbnailURL: entry.thumb,
            frames: entry.frames ?? []
        )
    }

    private static func loadBundledExercises() -> [BundledExercise] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([BundledExercise].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func loadMediaManifest() -> [String: ExerciseMediaEntry] {
        guard let url = Bundle.main.url(forResource: "exercise_media", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: ExerciseMediaEntry].self, from: data) else {
            return [:]
        }
        // Lower-case the keys so lookup is case-insensitive.
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.key.lowercased(), $0.value) })
    }

    /// Load wger.de imported exercises if `wger_exercises.json` is present
    /// in the bundle. The script `scripts/import_wger.py` writes that file;
    /// it's optional — missing-bundle returns []. License is CC-BY-SA 4.0,
    /// attributed in Profile → About.
    private static func loadWgerExercises() -> [ExerciseDemoInfo] {
        guard let url = Bundle.main.url(forResource: "wger_exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(WgerPayload.self, from: data) else {
            return []
        }
        return payload.exercises.map { row in
            ExerciseDemoInfo(
                name: row.name,
                instructions: row.instructions,
                tips: row.tips,
                primaryMuscles: row.primaryMuscles,
                secondaryMuscles: row.secondaryMuscles,
                videoURL: row.videoURL,
                thumbnailURL: row.thumbnailURL,
                frames: row.frames
            )
        }
    }
}

private struct WgerPayload: Decodable {
    let exercises: [WgerEntry]
}

private struct WgerEntry: Decodable {
    let name: String
    let instructions: [String]
    let tips: [String]
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let videoURL: String
    let thumbnailURL: String
    let frames: [String]
}

private struct ExerciseMediaEntry: Decodable, Sendable {
    let video: String
    let thumb: String
    let frames: [String]?
}

// MARK: - Bundled exercise schema (yuhonas/free-exercise-db)
//
// Mirrors the JSON entries in `exercises.json`. We map this into the
// app's `ExerciseDemoInfo` shape on load. Image paths reference the
// upstream sprite sheet — we don't ship those images yet, so the
// converted info has empty video/thumbnail URLs; the existing fallback
// in `info(for:)` handles missing media gracefully.
private struct BundledExercise: Decodable, Sendable {
    let id: String
    let name: String
    let force: String?
    let level: String?
    let mechanic: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let category: String?
    let images: [String]?

    func toDemoInfo() -> ExerciseDemoInfo {
        ExerciseDemoInfo(
            name: name,
            instructions: instructions,
            tips: BundledExercise.tipsFor(level: level, mechanic: mechanic, equipment: equipment),
            primaryMuscles: primaryMuscles.map { $0.capitalized },
            secondaryMuscles: secondaryMuscles.map { $0.capitalized },
            videoURL: "",
            thumbnailURL: ""
        )
    }

    /// Auto-generate a couple of generic tips from the metadata so the
    /// detail sheet doesn't show an empty Tips section. Hardcoded entries
    /// override these with real cues.
    private static func tipsFor(level: String?, mechanic: String?, equipment: String?) -> [String] {
        var tips: [String] = []
        if let lvl = level?.lowercased(), lvl == "beginner" {
            tips.append("Beginner-friendly — start light and dial in form before adding weight.")
        }
        if let mech = mechanic?.lowercased() {
            if mech == "compound" {
                tips.append("Compound lift — recruits multiple muscle groups; warm up thoroughly.")
            } else if mech == "isolation" {
                tips.append("Isolation movement — use a controlled tempo for full muscle activation.")
            }
        }
        if let eq = equipment?.lowercased(), eq != "body only" {
            tips.append("Equipment: \(eq.capitalized).")
        }
        if tips.isEmpty {
            tips.append("Use a weight that allows clean reps for the full set.")
        }
        return tips
    }
}
