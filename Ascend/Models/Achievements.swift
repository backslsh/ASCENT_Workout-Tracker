import SwiftUI

enum AchievementMetric: Hashable {
    case workouts, longestStreak, totalSets, maxSessionVolume, totalVolume, prs
    case bestTier, groupsRanked, overallTier, homeWorkouts, earlyBird, nightOwl, weighIns, longestSession

    enum Display { case count, weight, tier, minutes }

    var display: Display {
        switch self {
        case .maxSessionVolume, .totalVolume: return .weight
        case .bestTier, .overallTier: return .tier
        case .longestSession: return .minutes
        default: return .count
        }
    }
}

struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    /// `{w}` is replaced with the goal weight in the user's units.
    let detail: String
    let symbol: String
    let color: Color
    let metric: AchievementMetric
    /// Weight goals are in kg; tier goals are `RankTier.rawValue`; minutes for session length.
    let goal: Double
}

enum Achievements {
    private static let lb = 1 / 2.20462262

    static let all: [Achievement] = [
        .init(id: "first_workout", title: "First Rep", detail: "Finish your first workout",
              symbol: "figure.strengthtraining.traditional", color: Color(hex: 0x4BE3A0), metric: .workouts, goal: 1),
        .init(id: "workouts_10", title: "Getting Serious", detail: "Finish 10 workouts",
              symbol: "flame.fill", color: Color(hex: 0xFF9F43), metric: .workouts, goal: 10),
        .init(id: "workouts_50", title: "Committed", detail: "Finish 50 workouts",
              symbol: "medal.fill", color: Color(hex: 0xFFD84D), metric: .workouts, goal: 50),
        .init(id: "workouts_100", title: "Centurion", detail: "Finish 100 workouts",
              symbol: "star.circle.fill", color: Color(hex: 0x9CC8FF), metric: .workouts, goal: 100),
        .init(id: "workouts_250", title: "Iron Will", detail: "Finish 250 workouts",
              symbol: "crown.fill", color: Color(hex: 0xD3A6FF), metric: .workouts, goal: 250),
        .init(id: "streak_4", title: "Month Strong", detail: "Train 4 weeks in a row",
              symbol: "calendar.badge.checkmark", color: Color(hex: 0x3FD5FF), metric: .longestStreak, goal: 4),
        .init(id: "streak_12", title: "Unbreakable", detail: "Train 12 weeks in a row",
              symbol: "bolt.heart.fill", color: Color(hex: 0xFF5D6C), metric: .longestStreak, goal: 12),
        .init(id: "sets_500", title: "Set Machine", detail: "Complete 500 sets",
              symbol: "square.stack.3d.up.fill", color: Color(hex: 0x7C83FF), metric: .totalSets, goal: 500),
        .init(id: "sets_2500", title: "Volume Dealer", detail: "Complete 2,500 sets",
              symbol: "chart.bar.fill", color: Color(hex: 0xB57BFF), metric: .totalSets, goal: 2500),
        .init(id: "session_vol_1", title: "Heavy Day", detail: "Move {w} in one workout",
              symbol: "scalemass.fill", color: Color(hex: 0xFF6B8B), metric: .maxSessionVolume, goal: 10_000 * lb),
        .init(id: "session_vol_2", title: "Freight Train", detail: "Move {w} in one workout",
              symbol: "tram.fill", color: Color(hex: 0xE0244E), metric: .maxSessionVolume, goal: 25_000 * lb),
        .init(id: "total_vol", title: "Mountain Mover", detail: "Move {w} in total",
              symbol: "mountain.2.fill", color: Color(hex: 0x2ED3C6), metric: .totalVolume, goal: 1_000_000 * lb),
        .init(id: "prs_10", title: "Record Breaker", detail: "Set 10 personal records",
              symbol: "trophy.fill", color: Color(hex: 0xFFE07A), metric: .prs, goal: 10),
        .init(id: "prs_50", title: "PR Machine", detail: "Set 50 personal records",
              symbol: "trophy.circle.fill", color: Color(hex: 0xD99A1E), metric: .prs, goal: 50),
        .init(id: "tier_gold", title: "Golden", detail: "Reach Gold on any lift",
              symbol: "star.fill", color: Color(hex: 0xFFE07A), metric: .bestTier, goal: Double(RankTier.gold.rawValue)),
        .init(id: "tier_diamond", title: "Diamond Hands", detail: "Reach Diamond on any lift",
              symbol: "diamond.fill", color: Color(hex: 0x9CC8FF), metric: .bestTier, goal: Double(RankTier.diamond.rawValue)),
        .init(id: "tier_legend", title: "Living Legend", detail: "Reach Legend on any lift",
              symbol: "crown.fill", color: Color(hex: 0xFF5E8A), metric: .bestTier, goal: Double(RankTier.legend.rawValue)),
        .init(id: "all_groups", title: "Well Rounded", detail: "Get ranked in all 8 muscle groups",
              symbol: "circle.hexagongrid.fill", color: Color(hex: 0x3DDC97), metric: .groupsRanked, goal: 8),
        .init(id: "overall_plat", title: "Platinum Athlete", detail: "Reach an overall rank of Platinum",
              symbol: "sparkles", color: Color(hex: 0x8FF5E4), metric: .overallTier, goal: Double(RankTier.platinum.rawValue)),
        .init(id: "home_10", title: "Home Hero", detail: "Finish 10 home workouts (no barbell, machine or cable)",
              symbol: "house.fill", color: Color(hex: 0xFF9F43), metric: .homeWorkouts, goal: 10),
        .init(id: "early_bird", title: "Early Bird", detail: "Start a workout before 7 AM",
              symbol: "sunrise.fill", color: Color(hex: 0xFFB547), metric: .earlyBird, goal: 1),
        .init(id: "night_owl", title: "Night Owl", detail: "Start a workout after 9 PM",
              symbol: "moon.stars.fill", color: Color(hex: 0x7C83FF), metric: .nightOwl, goal: 1),
        .init(id: "weigh_ins", title: "On the Scale", detail: "Log your bodyweight 10 times",
              symbol: "chart.xyaxis.line", color: Color(hex: 0x4DA3FF), metric: .weighIns, goal: 10),
        .init(id: "marathon", title: "Marathon Session", detail: "Train for 90 minutes in one workout",
              symbol: "timer", color: Color(hex: 0x4BE3A0), metric: .longestSession, goal: 90),
    ]

    static func byID(_ id: String) -> Achievement? { all.first { $0.id == id } }
}
