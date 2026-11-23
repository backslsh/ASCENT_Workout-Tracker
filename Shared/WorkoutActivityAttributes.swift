import ActivityKit
import Foundation

/// Live Activity (lock screen + Dynamic Island) for an in-progress workout.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var restStart: Date?
        var restEnd: Date?
        var setsDone: Int
        var setsTotal: Int
        var exercise: String
    }

    var name: String
    var start: Date
    var accent: UInt32
    var accent2: UInt32
}

extension WorkoutActivityAttributes.ContentState {
    /// The running rest interval, if any (nil once it has expired / gone stale).
    func restRange(stale: Bool, now: Date = Date()) -> ClosedRange<Date>? {
        guard !stale, let a = restStart, let b = restEnd, b > a, b > now else { return nil }
        return a...b
    }
}
