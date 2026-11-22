import Foundation

/// Built-in exercises. `elite` = performance needed for the Legend rank (male standards; female standards are scaled).
enum ExerciseLibrary {
    static let all: [Exercise] = [
        // Chest
        e("bench_press", "Bench Press", .chest, .weighted, .barbell, 2.0),
        e("incline_bench", "Incline Bench Press", .chest, .weighted, .barbell, 1.7),
        e("db_bench", "Dumbbell Bench Press", .chest, .weighted, .dumbbell, 0.8),
        e("incline_db_press", "Incline Dumbbell Press", .chest, .weighted, .dumbbell, 0.7),
        e("db_fly", "Dumbbell Fly", .chest, .weighted, .dumbbell, 0.45),
        e("cable_fly", "Cable Fly", .chest, .weighted, .cable, 0.5),
        e("machine_chest_press", "Machine Chest Press", .chest, .weighted, .machine, 1.8),
        e("push_up", "Push-Up", .chest, .reps, .bodyweight, 75),
        e("wide_push_up", "Wide Push-Up", .chest, .reps, .bodyweight, 60),
        e("decline_push_up", "Decline Push-Up", .chest, .reps, .bodyweight, 55),
        e("chest_dip", "Chest Dip", .chest, .reps, .bodyweight, 40),

        // Back
        e("deadlift", "Deadlift", .back, .weighted, .barbell, 2.8),
        e("barbell_row", "Barbell Row", .back, .weighted, .barbell, 1.6),
        e("t_bar_row", "T-Bar Row", .back, .weighted, .barbell, 1.6),
        e("one_arm_db_row", "One-Arm Dumbbell Row", .back, .weighted, .dumbbell, 0.9),
        e("lat_pulldown", "Lat Pulldown", .back, .weighted, .cable, 1.4),
        e("seated_cable_row", "Seated Cable Row", .back, .weighted, .cable, 1.5),
        e("pull_up", "Pull-Up", .back, .reps, .bodyweight, 25),
        e("chin_up", "Chin-Up", .back, .reps, .bodyweight, 28),
        e("inverted_row", "Inverted Row", .back, .reps, .bodyweight, 35),
        e("back_extension", "Back Extension", .back, .reps, .bodyweight, 50),
        e("superman_hold", "Superman Hold", .back, .timed, .bodyweight, 180),

        // Shoulders
        e("overhead_press", "Overhead Press", .shoulders, .weighted, .barbell, 1.3),
        e("db_shoulder_press", "Dumbbell Shoulder Press", .shoulders, .weighted, .dumbbell, 0.55),
        e("arnold_press", "Arnold Press", .shoulders, .weighted, .dumbbell, 0.5),
        e("lateral_raise", "Lateral Raise", .shoulders, .weighted, .dumbbell, 0.3),
        e("front_raise", "Front Raise", .shoulders, .weighted, .dumbbell, 0.3),
        e("rear_delt_fly", "Rear Delt Fly", .shoulders, .weighted, .dumbbell, 0.3),
        e("face_pull", "Face Pull", .shoulders, .weighted, .cable, 0.8),
        e("upright_row", "Upright Row", .shoulders, .weighted, .barbell, 1.0),
        e("pike_push_up", "Pike Push-Up", .shoulders, .reps, .bodyweight, 40),
        e("handstand_push_up", "Handstand Push-Up", .shoulders, .reps, .bodyweight, 25),

        // Biceps
        e("barbell_curl", "Barbell Curl", .biceps, .weighted, .barbell, 0.9),
        e("db_curl", "Dumbbell Curl", .biceps, .weighted, .dumbbell, 0.45),
        e("hammer_curl", "Hammer Curl", .biceps, .weighted, .dumbbell, 0.5),
        e("preacher_curl", "Preacher Curl", .biceps, .weighted, .barbell, 0.75),
        e("concentration_curl", "Concentration Curl", .biceps, .weighted, .dumbbell, 0.4),
        e("cable_curl", "Cable Curl", .biceps, .weighted, .cable, 0.8),
        e("band_curl", "Band Curl", .biceps, .reps, .band, 60),

        // Triceps
        e("close_grip_bench", "Close-Grip Bench Press", .triceps, .weighted, .barbell, 1.7),
        e("skull_crusher", "Skull Crusher", .triceps, .weighted, .barbell, 0.9),
        e("tricep_pushdown", "Tricep Pushdown", .triceps, .weighted, .cable, 0.9),
        e("overhead_db_extension", "Overhead Dumbbell Extension", .triceps, .weighted, .dumbbell, 0.6),
        e("db_kickback", "Dumbbell Kickback", .triceps, .weighted, .dumbbell, 0.3),
        e("bench_dip", "Bench Dip", .triceps, .reps, .bodyweight, 60),
        e("diamond_push_up", "Diamond Push-Up", .triceps, .reps, .bodyweight, 50),

        // Legs
        e("back_squat", "Back Squat", .legs, .weighted, .barbell, 2.5),
        e("front_squat", "Front Squat", .legs, .weighted, .barbell, 2.0),
        e("leg_press", "Leg Press", .legs, .weighted, .machine, 4.5),
        e("goblet_squat", "Goblet Squat", .legs, .weighted, .dumbbell, 0.9),
        e("db_lunge", "Dumbbell Lunge", .legs, .weighted, .dumbbell, 0.6),
        e("bulgarian_split_squat", "Bulgarian Split Squat", .legs, .weighted, .dumbbell, 0.6),
        e("leg_extension", "Leg Extension", .legs, .weighted, .machine, 1.4),
        e("calf_raise", "Standing Calf Raise", .legs, .reps, .bodyweight, 100),
        e("bodyweight_squat", "Bodyweight Squat", .legs, .reps, .bodyweight, 100),
        e("jump_squat", "Jump Squat", .legs, .reps, .bodyweight, 50),
        e("wall_sit", "Wall Sit", .legs, .timed, .bodyweight, 240),

        // Glutes & hamstrings
        e("hip_thrust", "Hip Thrust", .glutes, .weighted, .barbell, 3.0),
        e("romanian_deadlift", "Romanian Deadlift", .glutes, .weighted, .barbell, 2.2),
        e("sumo_deadlift", "Sumo Deadlift", .glutes, .weighted, .barbell, 2.8),
        e("db_rdl", "Dumbbell Romanian Deadlift", .glutes, .weighted, .dumbbell, 0.9),
        e("good_morning", "Good Morning", .glutes, .weighted, .barbell, 1.4),
        e("leg_curl", "Leg Curl", .glutes, .weighted, .machine, 1.0),
        e("kb_swing", "Kettlebell Swing", .glutes, .weighted, .kettlebell, 0.7),
        e("glute_bridge", "Glute Bridge", .glutes, .reps, .bodyweight, 60),

        // Core
        e("plank", "Plank", .core, .timed, .bodyweight, 300),
        e("side_plank", "Side Plank", .core, .timed, .bodyweight, 150),
        e("hollow_hold", "Hollow Hold", .core, .timed, .bodyweight, 150),
        e("russian_twist", "Russian Twist", .core, .reps, .bodyweight, 80),
        e("crunch", "Crunch", .core, .reps, .bodyweight, 80),
        e("sit_up", "Sit-Up", .core, .reps, .bodyweight, 70),
        e("bicycle_crunch", "Bicycle Crunch", .core, .reps, .bodyweight, 90),
        e("leg_raise", "Lying Leg Raise", .core, .reps, .bodyweight, 50),
        e("hanging_leg_raise", "Hanging Leg Raise", .core, .reps, .bodyweight, 30),
        e("v_up", "V-Up", .core, .reps, .bodyweight, 50),
        e("mountain_climber", "Mountain Climber", .core, .reps, .bodyweight, 100),
        e("dead_bug", "Dead Bug", .core, .reps, .bodyweight, 60),
        e("ab_wheel", "Ab Wheel Rollout", .core, .reps, .other, 35),
        e("cable_crunch", "Cable Crunch", .core, .weighted, .cable, 1.2),
    ]

    private static func e(_ id: String, _ name: String, _ m: MuscleGroup, _ k: ExerciseKind, _ eq: Equipment, _ elite: Double) -> Exercise {
        Exercise(id: id, name: name, muscle: m, kind: k, equipment: eq, elite: elite, isCustom: false)
    }

    static func defaultElite(kind: ExerciseKind, equipment: Equipment) -> Double {
        switch kind {
        case .reps: return 50
        case .timed: return 180
        case .weighted:
            switch equipment {
            case .barbell, .machine: return 1.5
            case .dumbbell, .kettlebell: return 0.6
            default: return 1.0
            }
        }
    }
}

enum Templates {
    static var routines: [Routine] {
        [
            make("Home Dumbbell Full Body", pinned: true, [
                ("goblet_squat", 3, 12), ("db_bench", 3, 10), ("one_arm_db_row", 3, 10),
                ("db_shoulder_press", 3, 10), ("db_rdl", 3, 10), ("russian_twist", 3, 20),
            ]),
            make("Core Crusher", pinned: true, [
                ("plank", 3, 60), ("russian_twist", 3, 24), ("bicycle_crunch", 3, 20),
                ("leg_raise", 3, 15), ("mountain_climber", 3, 30),
            ]),
            make("Push Day", [
                ("bench_press", 4, 8), ("overhead_press", 3, 8), ("incline_db_press", 3, 10),
                ("lateral_raise", 3, 15), ("tricep_pushdown", 3, 12),
            ]),
            make("Pull Day", [
                ("deadlift", 3, 5), ("pull_up", 3, 8), ("barbell_row", 3, 8),
                ("face_pull", 3, 15), ("db_curl", 3, 12),
            ]),
            make("Leg Day", [
                ("back_squat", 4, 6), ("romanian_deadlift", 3, 8), ("leg_press", 3, 10),
                ("leg_curl", 3, 12), ("calf_raise", 4, 15),
            ]),
        ]
    }

    static func make(_ name: String, pinned: Bool = false, _ items: [(String, Int, Int)]) -> Routine {
        let entries: [ExerciseEntry] = items.compactMap { item in
            let (id, count, target) = item
            guard let ex = ExerciseLibrary.all.first(where: { $0.id == id }) else { return nil }
            let sets: [SetEntry] = (0..<count).map { _ in
                ex.kind == .timed ? SetEntry(seconds: target) : SetEntry(reps: target)
            }
            return ExerciseEntry(exerciseID: id, sets: sets, restSeconds: ex.kind == .weighted ? 90 : 45)
        }
        return Routine(name: name, entries: entries, pinned: pinned)
    }
}
