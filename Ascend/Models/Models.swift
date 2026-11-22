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
}

struct AppData: Codable {
    var profile: Profile
    var routines: [Routine]
    var sessions: [WorkoutSession]
    var customExercises: [Exercise]
    var active: WorkoutSession?
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
