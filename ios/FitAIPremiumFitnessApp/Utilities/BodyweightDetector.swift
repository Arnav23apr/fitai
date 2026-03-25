import Foundation

struct BodyweightDetector {
    private static let bodyweightExercises: Set<String> = [
        "push-up", "push up", "pushup", "push-ups", "push ups", "pushups",
        "pull-up", "pull up", "pullup", "pull-ups", "pull ups", "pullups",
        "chin-up", "chin up", "chinup", "chin-ups", "chin ups", "chinups",
        "dip", "dips", "tricep dip", "tricep dips", "chest dip", "chest dips",
        "bodyweight squat", "body weight squat", "air squat", "air squats",
        "lunge", "lunges", "walking lunge", "walking lunges", "reverse lunge", "reverse lunges",
        "step-up", "step up", "step-ups", "step ups",
        "plank", "planks", "side plank", "side planks",
        "crunch", "crunches", "sit-up", "sit up", "sit-ups", "sit ups", "situp", "situps",
        "leg raise", "leg raises", "hanging leg raise", "hanging leg raises",
        "mountain climber", "mountain climbers",
        "burpee", "burpees",
        "jumping jack", "jumping jacks",
        "pike push-up", "pike push up", "pike pushup",
        "diamond push-up", "diamond push up", "diamond pushup",
        "decline push-up", "decline push up", "decline pushup",
        "incline push-up", "incline push up", "incline pushup",
        "wide push-up", "wide push up", "wide pushup",
        "inverted row", "inverted rows", "body row", "body rows",
        "muscle-up", "muscle up", "muscle-ups", "muscle ups",
        "pistol squat", "pistol squats",
        "bulgarian split squat", "bulgarian split squats",
        "calf raise", "calf raises", "bodyweight calf raise",
        "glute bridge", "glute bridges", "hip thrust", "hip thrusts",
        "superman", "supermans", "back extension", "back extensions",
        "flutter kick", "flutter kicks",
        "bicycle crunch", "bicycle crunches",
        "russian twist", "russian twists",
        "v-up", "v up", "v-ups", "v ups",
        "hanging knee raise", "hanging knee raises",
        "dead hang",
        "wall sit", "wall sits",
        "bear crawl",
        "box jump", "box jumps",
        "squat jump", "squat jumps", "jump squat", "jump squats",
        "tuck jump", "tuck jumps",
    ]

    private static let bodyweightKeywords: [String] = [
        "bodyweight", "body weight", "bw ", "calisthenics",
        "push-up", "push up", "pushup",
        "pull-up", "pull up", "pullup",
        "chin-up", "chin up", "chinup",
        "plank", "crunch", "sit-up", "situp",
        "leg raise", "burpee", "dip",
        "lunge", "pistol squat",
        "muscle-up", "muscle up",
        "inverted row", "glute bridge",
        "superman", "flutter kick",
        "bicycle crunch", "russian twist",
        "v-up", "hanging",
        "mountain climber", "jumping jack",
        "wall sit", "bear crawl",
        "box jump", "jump squat", "squat jump", "tuck jump",
    ]

    private static let equipmentOnlyExercises: Set<String> = [
        "bench press", "barbell bench press", "incline bench press", "decline bench press",
        "dumbbell bench press", "incline dumbbell press", "dumbbell press",
        "lat pulldown", "cable row", "seated cable row", "cable rows",
        "cable flyes", "cable fly", "cable crossovers", "cable crossover",
        "leg press", "leg extension", "leg extensions", "leg curl", "leg curls",
        "hack squat", "smith machine squat",
        "tricep pushdowns", "tricep pushdown", "cable tricep pushdown",
        "overhead tricep extension", "skull crushers", "skull crusher",
        "preacher curls", "preacher curl", "incline curls", "incline curl",
        "barbell curls", "barbell curl", "hammer curls", "hammer curl",
        "barbell rows", "barbell row", "t-bar row", "t-bar rows",
        "overhead press", "barbell overhead press", "military press",
        "arnold press", "dumbbell shoulder press",
        "barbell squat", "front squats", "front squat",
        "romanian deadlift", "deadlift", "sumo deadlift",
        "hip thrusts", "hip thrust", "barbell hip thrust",
        "cable woodchops", "cable woodchop",
        "cable crunches", "cable crunch",
        "face pulls", "face pull",
        "lateral raises", "lateral raise",
        "rear delt flyes", "rear delt fly", "reverse flyes",
        "straight arm pulldown", "straight arm pulldowns",
        "seated calf raise", "seated calf raises",
    ]

    private static let equipmentKeywords: [String] = [
        "barbell", "dumbbell", "cable", "machine", "smith",
        "lat pulldown", "leg press", "leg extension", "leg curl",
        "hack squat", "preacher", "t-bar",
    ]

    static func isBodyweightExercise(_ name: String) -> Bool {
        let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
        if bodyweightExercises.contains(lower) {
            return true
        }
        for keyword in bodyweightKeywords {
            if lower.contains(keyword) {
                return true
            }
        }
        return false
    }

    static func isEquipmentOnly(_ name: String) -> Bool {
        let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
        if equipmentOnlyExercises.contains(lower) {
            return true
        }
        for keyword in equipmentKeywords {
            if lower.contains(keyword) {
                return true
            }
        }
        return false
    }
}
