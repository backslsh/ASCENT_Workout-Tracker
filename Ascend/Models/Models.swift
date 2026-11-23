import SwiftUI
import UIKit

// MARK: - Muscle groups

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest, back, shoulders, biceps, triceps, legs, glutes, core

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .legs: return "Legs"
        case .glutes: return "Glutes & Hams"
        case .core: return "Core"
        }
    }

    var symbol: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.rower"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.strengthtraining.functional"
        case .triceps: return "figure.strengthtraining.traditional"
        case .legs: return "figure.step.training"
        case .glutes: return "figure.cross.training"
        case .core: return "figure.core.training"
        }
    }

    var color: Color {
        switch self {
        case .chest: return Color(hex: 0xFF6B8B)
        case .back: return Color(hex: 0x4DA3FF)
        case .shoulders: return Color(hex: 0xFF9F43)
        case .biceps: return Color(hex: 0xB57BFF)
        case .triceps: return Color(hex: 0x7C83FF)
        case .legs: return Color(hex: 0x3DDC97)
        case .glutes: return Color(hex: 0x2ED3C6)
        case .core: return Color(hex: 0xFFD84D)
        }
    }
}

// MARK: - Exercises

enum ExerciseKind: String, Codable, CaseIterable, Identifiable {
    case weighted, reps, timed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .weighted: return "Weight × Reps"
        case .reps: return "Bodyweight Reps"
        case .timed: return "Timed Hold"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, machine, cable, kettlebell, bodyweight, band, other
    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .machine: return "gearshape.2.fill"
        case .cable: return "cable.connector"
        case .kettlebell: return "scalemass.fill"
        case .bodyweight: return "figure.walk"
        case .band: return "arrow.left.and.right"
        case .other: return "ellipsis.circle"
        }
    }

    var ownedName: String {
        switch self {
        case .barbell: return "Barbell & plates"
        case .dumbbell: return "Dumbbells"
        case .machine: return "Machines"
        case .cable: return "Cable station"
        case .kettlebell: return "Kettlebells"
        case .bodyweight: return "Bodyweight"
        case .band: return "Resistance bands"
        case .other: return "Other"
        }
    }

    /// Equipment you'd typically have at home.
    var isHome: Bool { [.dumbbell, .kettlebell, .bodyweight, .band].contains(self) }
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var muscle: MuscleGroup
    var kind: ExerciseKind
    var equipment: Equipment
    /// Performance that maps to the top ("Legend") rank. Weighted: est. 1RM ÷ bodyweight. Reps: reps. Timed: seconds.
    var elite: Double
    var isCustom: Bool = false

    static let unknown = Exercise(id: "unknown", name: "Unknown Exercise", muscle: .core, kind: .reps, equipment: .other, elite: 50)
}

// MARK: - Sets, routines, sessions

struct SetEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Always stored in kilograms (for bodyweight / timed moves this is *added* weight).
    var weight: Double = 0
    var reps: Int = 0
    var seconds: Int = 0
    var done: Bool = false
    var isWarmup: Bool = false
}

struct ExerciseEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: [SetEntry]
    var restSeconds: Int
    var note: String = ""
    /// Entries next to each other that share this ID form a superset / circuit.
    var supersetID: UUID? = nil
}

struct Routine: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var entries: [ExerciseEntry]
    var pinned: Bool = false
    var lastUsed: Date? = nil
    var created: Date = Date()
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var routineID: UUID?
    var start: Date
    var end: Date?
    var entries: [ExerciseEntry]
    var bodyweight: Double?

    static let empty = WorkoutSession(name: "", routineID: nil, start: Date(), end: nil, entries: [], bodyweight: nil)

    var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
    var completedSets: Int { entries.reduce(0) { $0 + $1.sets.filter { $0.done }.count } }
    var volume: Double {
        entries.reduce(0) { acc, e in
            acc + e.sets.filter { $0.done }.reduce(0) { $0 + $1.weight * Double($1.reps) }
        }
    }
}

// MARK: - Profile

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    func display(_ kg: Double) -> Double { self == .kg ? kg : kg * 2.20462262 }
    func toKg(_ v: Double) -> Double { self == .kg ? v : v / 2.20462262 }
}

enum StandardSex: String, Codable, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
}

struct Profile: Codable, Hashable {
    var name: String = ""
    var age: Int = 25
    var bodyweight: Double = 75
    var units: UnitSystem = .lb
    var sex: StandardSex = .male
    var showcase: [String] = []
    var defaultRest: Int = 90
    var weeklyGoal: Int = 4
    var onboarded: Bool = false
    var restNotifications: Bool = true
    var accent: AccentTheme = .aurora
    var sounds: Bool = true
    var myEquipment: [Equipment] = []
    var equipmentFilter: Bool = false
    var barKg: Double? = nil
    var autoBackup: Bool = true
    var liveActivity: Bool = true

    enum CodingKeys: String, CodingKey {
        case name, age, bodyweight, units, sex, showcase, defaultRest, weeklyGoal, onboarded, restNotifications
        case accent, sounds, myEquipment, equipmentFilter, barKg, autoBackup, liveActivity
    }
}

extension Profile {
    /// Tolerant decoding: missing or unknown values fall back to defaults, so older data files always load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ d: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? d }
        self.init()
        name = v(.name, name)
        age = v(.age, age)
        bodyweight = v(.bodyweight, bodyweight)
        units = v(.units, units)
        sex = v(.sex, sex)
        showcase = v(.showcase, showcase)
        defaultRest = v(.defaultRest, defaultRest)
        weeklyGoal = v(.weeklyGoal, weeklyGoal)
        onboarded = v(.onboarded, onboarded)
        restNotifications = v(.restNotifications, restNotifications)
        accent = v(.accent, accent)
        sounds = v(.sounds, sounds)
        myEquipment = v(.myEquipment, myEquipment)
        equipmentFilter = v(.equipmentFilter, equipmentFilter)
        barKg = (try? c.decodeIfPresent(Double.self, forKey: .barKg)) ?? nil
        autoBackup = v(.autoBackup, autoBackup)
        liveActivity = v(.liveActivity, liveActivity)
    }
}

// MARK: - Accent themes

enum AccentTheme: String, Codable, CaseIterable, Identifiable {
    case aurora, ocean, ember, crimson, emerald, gold, rose

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var hex: (UInt32, UInt32) {
        switch self {
        case .aurora: return (0x8C7BFF, 0x3FD5FF)
        case .ocean: return (0x3F8CFF, 0x3FF0D2)
        case .ember: return (0xFF6A3D, 0xFFC93F)
        case .crimson: return (0xFF3D6E, 0xFF8A5C)
        case .emerald: return (0x2FD68A, 0x3FC8FF)
        case .gold: return (0xF5B83D, 0xFFE58A)
        case .rose: return (0xFF6FB5, 0xB57BFF)
        }
    }

    var accent: Color { Color(hex: hex.0) }
    var accent2: Color { Color(hex: hex.1) }
}

// MARK: - Bodyweight log

struct WeightEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var kg: Double
}

struct AppData: Codable {
    var profile: Profile
    var routines: [Routine]
    var sessions: [WorkoutSession]
    var customExercises: [Exercise]
    var active: WorkoutSession?
    var exerciseNotes: [String: String]? = nil
    var weightLog: [WeightEntry]? = nil
    var achievements: [String: Date]? = nil
    var lastAutoBackup: Date? = nil
}

// MARK: - Formatting helpers

func fmtNumber(_ v: Double) -> String {
    v.formatted(.number.precision(.fractionLength(0...1)))
}

func fmtDuration(_ t: TimeInterval) -> String {
    let s = Int(max(0, t))
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}

func fmtShortDuration(_ t: TimeInterval) -> String {
    let m = Int(max(0, t)) / 60
    return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
}

func fmtRest(_ s: Int) -> String {
    if s == 0 { return "Off" }
    if s < 60 { return "\(s)s" }
    if s % 60 == 0 { return "\(s / 60) min" }
    return String(format: "%d:%02d", s / 60, s % 60)
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
