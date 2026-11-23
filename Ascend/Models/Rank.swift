import SwiftUI

enum RankTier: Int, CaseIterable, Comparable, Hashable, Identifiable {
    case iron, bronze, silver, gold, platinum, diamond, master, grandmaster, legend

    var id: Int { rawValue }
    static func < (l: RankTier, r: RankTier) -> Bool { l.rawValue < r.rawValue }

    var name: String {
        switch self {
        case .iron: return "Iron"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        case .master: return "Master"
        case .grandmaster: return "Grandmaster"
        case .legend: return "Legend"
        }
    }

    /// Fraction of the elite standard needed to enter this tier.
    var threshold: Double {
        [0, 0.18, 0.32, 0.46, 0.58, 0.70, 0.81, 0.91, 1.0][rawValue]
    }

    var hexColors: [UInt32] {
        switch self {
        case .iron: return [0x9AA0A9, 0x4A4E55]
        case .bronze: return [0xE8A86E, 0x8C5326]
        case .silver: return [0xE6ECF2, 0x7F8A97]
        case .gold: return [0xFFE07A, 0xD99A1E]
        case .platinum: return [0x8FF5E4, 0x1F9E8F]
        case .diamond: return [0x9CC8FF, 0x3D6BFF]
        case .master: return [0xD3A6FF, 0x7B3FE4]
        case .grandmaster: return [0xFF9AAE, 0xE0244E]
        case .legend: return [0xFFD36E, 0xFF5E8A, 0x8C5CFF]
        }
    }

    var colors: [Color] { hexColors.map { Color(hex: $0) } }

    var symbol: String {
        switch self {
        case .iron: return "hammer.fill"
        case .bronze: return "shield.fill"
        case .silver: return "shield.lefthalf.filled"
        case .gold: return "star.fill"
        case .platinum: return "sparkle"
        case .diamond: return "diamond.fill"
        case .master: return "flame.fill"
        case .grandmaster: return "bolt.fill"
        case .legend: return "crown.fill"
        }
    }

    var next: RankTier? { RankTier(rawValue: rawValue + 1) }
    var glows: Bool { self >= .diamond }
}

struct RankInfo: Hashable {
    let tier: RankTier
    /// 3 = III (lowest), 1 = I (highest). 0 for Legend.
    let division: Int
    let score: Double
    /// Progress toward the next division, 0...1.
    let progress: Double
    let nextThreshold: Double?

    var title: String { division == 0 ? tier.name : "\(tier.name) \(["", "I", "II", "III"][division])" }
    var ordinal: Int { tier == .legend ? 100 : tier.rawValue * 3 + (3 - division) }
    var color: Color { tier.colors[0] }

    var nextTitle: String? {
        guard let n = nextThreshold else { return nil }
        return RankInfo.from(score: n + 1e-6).title
    }

    static func from(score: Double) -> RankInfo {
        let s = max(0, score)
        if s >= RankTier.legend.threshold {
            return RankInfo(tier: .legend, division: 0, score: s, progress: 1, nextThreshold: nil)
        }
        var tier = RankTier.iron
        for t in RankTier.allCases where s >= t.threshold { tier = t }
        let lo = tier.threshold
        let hi = (tier.next ?? .legend).threshold
        let step = (hi - lo) / 3
        let idx = min(2, Int((s - lo) / step))
        let stepLo = lo + Double(idx) * step
        return RankInfo(tier: tier, division: 3 - idx, score: s,
                        progress: min(1, max(0, (s - stepLo) / step)),
                        nextThreshold: stepLo + step)
    }

    /// A representative badge for a tier (used in the ladder).
    static func display(_ t: RankTier) -> RankInfo {
        RankInfo(tier: t, division: t == .legend ? 0 : 1, score: t.threshold, progress: 0, nextThreshold: nil)
    }
}

enum RankEngine {
    /// Epley estimated one-rep max.
    static func e1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(min(reps, 20)) / 30)
    }

    static func performance(of set: SetEntry, exercise: Exercise, bodyweight: Double) -> Double {
        let bw = max(bodyweight, 30)
        switch exercise.kind {
        case .weighted: return e1RM(weight: set.weight, reps: set.reps) / bw
        case .reps: return Double(set.reps) * (1 + 2 * set.weight / bw)
        case .timed: return Double(set.seconds) * (1 + 2 * set.weight / bw)
        }
    }

    private static func factor(_ ex: Exercise, _ sex: StandardSex) -> Double {
        if sex == .male || ex.kind == .timed { return 1 }
        return 0.7
    }

    static func score(perf: Double, exercise: Exercise, sex: StandardSex) -> Double {
        perf / (exercise.elite * factor(exercise, sex))
    }

    static func perfNeeded(score: Double, exercise: Exercise, sex: StandardSex) -> Double {
        score * exercise.elite * factor(exercise, sex)
    }
}
