import Foundation
import MuscleMap

nonisolated struct MuscleMapping: Sendable {
    let primary: [Muscle]
    let secondary: [Muscle]
}

class MuscleMapperService {
    static let shared = MuscleMapperService()

    func mapping(for exerciseName: String, muscleGroup: String) -> MuscleMapping {
        let name = exerciseName.lowercased()
        let group = muscleGroup.lowercased()

        if let specific = specificExerciseMapping(name) {
            return specific
        }

        return groupBasedMapping(group)
    }

    func primaryMuscles(for exercises: [Exercise]) -> [Muscle] {
        var muscles = Set<Muscle>()
        for exercise in exercises {
            let m = mapping(for: exercise.name, muscleGroup: exercise.muscleGroup)
            muscles.formUnion(m.primary)
        }
        return Array(muscles)
    }

    func secondaryMuscles(for exercises: [Exercise]) -> [Muscle] {
        var muscles = Set<Muscle>()
        let primaries = Set(primaryMuscles(for: exercises))
        for exercise in exercises {
            let m = mapping(for: exercise.name, muscleGroup: exercise.muscleGroup)
            for s in m.secondary where !primaries.contains(s) {
                muscles.insert(s)
            }
        }
        return Array(muscles)
    }

    func muscleToString(_ muscle: Muscle) -> String {
        switch muscle {
        case .chest: return "Chest"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .deltoids: return "Shoulders"
        case .trapezius: return "Traps"
        case .quadriceps: return "Quads"
        case .hamstring: return "Hamstrings"
        case .calves: return "Calves"
        case .gluteal: return "Glutes"
        case .abs: return "Abs"
        case .obliques: return "Obliques"
        case .forearm: return "Forearms"
        case .lowerBack: return "Lower Back"
        case .upperBack: return "Upper Back"
        default: return muscle.displayName
        }
    }

    func exercisesTargeting(muscle: Muscle, from exercises: [Exercise]) -> [Exercise] {
        exercises.filter { exercise in
            let m = mapping(for: exercise.name, muscleGroup: exercise.muscleGroup)
            return m.primary.contains(muscle) || m.secondary.contains(muscle)
        }
    }

    private func specificExerciseMapping(_ name: String) -> MuscleMapping? {
        if name.contains("bench press") || name.contains("dumbbell bench") || name.contains("dumbbell press") {
            if name.contains("incline") {
                return MuscleMapping(primary: [.chest], secondary: [.deltoids, .triceps])
            }
            if name.contains("decline") {
                return MuscleMapping(primary: [.chest], secondary: [.triceps])
            }
            return MuscleMapping(primary: [.chest], secondary: [.deltoids, .triceps])
        }
        if name.contains("push-up") || name.contains("push up") || name.contains("pushup") {
            if name.contains("diamond") {
                return MuscleMapping(primary: [.triceps, .chest], secondary: [.deltoids])
            }
            if name.contains("pike") {
                return MuscleMapping(primary: [.deltoids], secondary: [.triceps, .chest])
            }
            if name.contains("decline") {
                return MuscleMapping(primary: [.chest], secondary: [.deltoids, .triceps])
            }
            if name.contains("wide") {
                return MuscleMapping(primary: [.chest], secondary: [.deltoids, .triceps])
            }
            return MuscleMapping(primary: [.chest], secondary: [.triceps, .deltoids])
        }
        if name.contains("cable flye") || name.contains("cable crossover") {
            return MuscleMapping(primary: [.chest], secondary: [.deltoids])
        }
        if name.contains("overhead press") || name.contains("arnold press") || name.contains("shoulder press") {
            return MuscleMapping(primary: [.deltoids], secondary: [.triceps, .trapezius])
        }
        if name.contains("lateral raise") {
            return MuscleMapping(primary: [.deltoids], secondary: [])
        }
        if name.contains("face pull") {
            return MuscleMapping(primary: [.deltoids], secondary: [.trapezius, .upperBack])
        }
        if name.contains("barbell row") || name.contains("bent-over row") || name.contains("t-bar row") {
            return MuscleMapping(primary: [.upperBack], secondary: [.biceps, .lowerBack, .trapezius])
        }
        if name.contains("cable row") || name.contains("seated cable") {
            return MuscleMapping(primary: [.upperBack], secondary: [.biceps, .trapezius])
        }
        if name.contains("lat pulldown") || name.contains("straight arm pulldown") {
            return MuscleMapping(primary: [.upperBack], secondary: [.biceps])
        }
        if name.contains("pull-up") || name.contains("pull up") || name.contains("pullup") {
            return MuscleMapping(primary: [.upperBack], secondary: [.biceps, .forearm])
        }
        if name.contains("chin-up") || name.contains("chin up") {
            return MuscleMapping(primary: [.biceps, .upperBack], secondary: [.forearm])
        }
        if name.contains("inverted row") {
            return MuscleMapping(primary: [.upperBack], secondary: [.biceps, .deltoids])
        }
        if name.contains("deadlift") {
            if name.contains("romanian") || name.contains("rdl") || name.contains("single leg") {
                return MuscleMapping(primary: [.hamstring, .gluteal], secondary: [.lowerBack])
            }
            return MuscleMapping(primary: [.hamstring, .lowerBack, .gluteal], secondary: [.quadriceps, .trapezius, .forearm])
        }
        if name.contains("squat") {
            if name.contains("front") {
                return MuscleMapping(primary: [.quadriceps], secondary: [.gluteal, .abs])
            }
            if name.contains("hack") {
                return MuscleMapping(primary: [.quadriceps], secondary: [.gluteal])
            }
            if name.contains("bulgarian") || name.contains("split") {
                return MuscleMapping(primary: [.quadriceps, .gluteal], secondary: [.hamstring])
            }
            if name.contains("jump") {
                return MuscleMapping(primary: [.quadriceps], secondary: [.gluteal, .calves])
            }
            if name.contains("pistol") {
                return MuscleMapping(primary: [.quadriceps], secondary: [.gluteal, .hamstring])
            }
            if name.contains("bodyweight") || name.contains("wall sit") {
                return MuscleMapping(primary: [.quadriceps], secondary: [.gluteal])
            }
            return MuscleMapping(primary: [.quadriceps, .gluteal], secondary: [.hamstring, .lowerBack, .abs])
        }
        if name.contains("leg press") {
            return MuscleMapping(primary: [.quadriceps], secondary: [.gluteal, .hamstring])
        }
        if name.contains("leg extension") {
            return MuscleMapping(primary: [.quadriceps], secondary: [])
        }
        if name.contains("leg curl") {
            return MuscleMapping(primary: [.hamstring], secondary: [.calves])
        }
        if name.contains("lunge") || name.contains("walking lunge") {
            return MuscleMapping(primary: [.quadriceps, .gluteal], secondary: [.hamstring])
        }
        if name.contains("hip thrust") || name.contains("glute bridge") {
            return MuscleMapping(primary: [.gluteal], secondary: [.hamstring])
        }
        if name.contains("calf raise") || name.contains("calf") {
            return MuscleMapping(primary: [.calves], secondary: [])
        }
        if name.contains("barbell curl") || name.contains("bicep curl") || name.contains("incline curl") || name.contains("preacher curl") || name.contains("doorway curl") {
            return MuscleMapping(primary: [.biceps], secondary: [.forearm])
        }
        if name.contains("hammer curl") {
            return MuscleMapping(primary: [.biceps], secondary: [.forearm])
        }
        if name.contains("tricep pushdown") || name.contains("tricep extension") || name.contains("overhead tricep") || name.contains("skull crusher") {
            return MuscleMapping(primary: [.triceps], secondary: [])
        }
        if name.contains("dip") {
            return MuscleMapping(primary: [.triceps, .chest], secondary: [.deltoids])
        }
        if name.contains("plank") {
            return MuscleMapping(primary: [.abs], secondary: [.obliques, .deltoids])
        }
        if name.contains("crunch") || name.contains("cable crunch") {
            if name.contains("bicycle") {
                return MuscleMapping(primary: [.abs, .obliques], secondary: [])
            }
            return MuscleMapping(primary: [.abs], secondary: [])
        }
        if name.contains("hanging leg raise") || name.contains("hanging knee raise") {
            return MuscleMapping(primary: [.abs], secondary: [.obliques, .forearm])
        }
        if name.contains("woodchop") {
            return MuscleMapping(primary: [.obliques], secondary: [.abs])
        }
        if name.contains("mountain climber") {
            return MuscleMapping(primary: [.abs], secondary: [.deltoids, .quadriceps])
        }
        if name.contains("superman") {
            return MuscleMapping(primary: [.lowerBack], secondary: [.gluteal])
        }
        if name.contains("foam rolling") || name.contains("stretch") || name.contains("cat-cow") {
            return MuscleMapping(primary: [], secondary: [])
        }
        if name.contains("walk") && !name.contains("lunge") {
            return MuscleMapping(primary: [], secondary: [])
        }
        return nil
    }

    private func groupBasedMapping(_ group: String) -> MuscleMapping {
        if group.contains("chest") {
            return MuscleMapping(primary: [.chest], secondary: [.triceps, .deltoids])
        }
        if group.contains("upper chest") {
            return MuscleMapping(primary: [.chest], secondary: [.deltoids, .triceps])
        }
        if group.contains("shoulder") || group.contains("delt") {
            if group.contains("rear") {
                return MuscleMapping(primary: [.deltoids], secondary: [.trapezius, .upperBack])
            }
            if group.contains("side") {
                return MuscleMapping(primary: [.deltoids], secondary: [])
            }
            return MuscleMapping(primary: [.deltoids], secondary: [.triceps])
        }
        if group.contains("back") || group.contains("lat") {
            if group.contains("lower") {
                return MuscleMapping(primary: [.lowerBack], secondary: [.gluteal])
            }
            if group.contains("mid") {
                return MuscleMapping(primary: [.upperBack], secondary: [.trapezius])
            }
            return MuscleMapping(primary: [.upperBack], secondary: [.biceps])
        }
        if group.contains("bicep") {
            return MuscleMapping(primary: [.biceps], secondary: [.forearm])
        }
        if group.contains("tricep") {
            return MuscleMapping(primary: [.triceps], secondary: [])
        }
        if group.contains("quad") {
            return MuscleMapping(primary: [.quadriceps], secondary: [.gluteal])
        }
        if group.contains("hamstring") {
            return MuscleMapping(primary: [.hamstring], secondary: [.gluteal])
        }
        if group.contains("glute") {
            return MuscleMapping(primary: [.gluteal], secondary: [.hamstring])
        }
        if group.contains("calve") || group.contains("calf") {
            return MuscleMapping(primary: [.calves], secondary: [])
        }
        if group.contains("core") || group.contains("abs") {
            return MuscleMapping(primary: [.abs], secondary: [.obliques])
        }
        if group.contains("oblique") {
            return MuscleMapping(primary: [.obliques], secondary: [.abs])
        }
        if group.contains("forearm") {
            return MuscleMapping(primary: [.forearm], secondary: [])
        }
        if group.contains("trap") {
            return MuscleMapping(primary: [.trapezius], secondary: [])
        }
        if group.contains("leg") {
            return MuscleMapping(primary: [.quadriceps, .hamstring], secondary: [.gluteal, .calves])
        }
        if group.contains("hip") {
            return MuscleMapping(primary: [.gluteal], secondary: [.quadriceps])
        }
        if group.contains("full body") || group.contains("cardio") || group.contains("spine") {
            return MuscleMapping(primary: [], secondary: [])
        }
        return MuscleMapping(primary: [], secondary: [])
    }
}
