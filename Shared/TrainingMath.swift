import Foundation

/// Date math shared by the app and the widget extension.
enum TrainingMath {
    static func workoutsThisWeek(_ dates: [Date], now: Date = Date()) -> Int {
        let cal = Calendar.current
        return dates.filter { cal.isDate($0, equalTo: now, toGranularity: .weekOfYear) }.count
    }

    /// Consecutive weeks (ending this week, or last week if this week has no workout yet) with at least one workout.
    static func weekStreak(_ dates: [Date], now: Date = Date()) -> Int {
        let cal = Calendar.current
        guard var week = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        let starts = Set(dates.compactMap { cal.dateInterval(of: .weekOfYear, for: $0)?.start })
        if !starts.contains(week) { week = cal.date(byAdding: .weekOfYear, value: -1, to: week) ?? week }
        var streak = 0
        while starts.contains(week) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = prev
        }
        return streak
    }

    static func longestWeekStreak(_ dates: [Date]) -> Int {
        let cal = Calendar.current
        let starts = Set(dates.compactMap { cal.dateInterval(of: .weekOfYear, for: $0)?.start }).sorted()
        var best = 0, run = 0
        var prev: Date?
        for w in starts {
            if let p = prev, let next = cal.date(byAdding: .weekOfYear, value: 1, to: p), cal.isDate(next, inSameDayAs: w) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            prev = w
        }
        return best
    }
}
