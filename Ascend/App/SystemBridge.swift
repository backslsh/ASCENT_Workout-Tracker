import ActivityKit
import WidgetKit
import Foundation

// Live Activity (lock screen / Dynamic Island) and home-screen widget plumbing.
// Neither needs a paid developer account: Live Activities use no entitlement, and the widget
// reads a small JSON file from the App Group container (if the signer kept the App Group).

extension AppStore {
    func liveState() -> WorkoutActivityAttributes.ContentState? {
        guard let s = active else { return nil }
        let total = s.entries.reduce(0) { $0 + $1.sets.count }
        let current = s.entries.first { e in e.sets.contains { !$0.done } } ?? s.entries.last
        let name = current.flatMap { exercise($0.exerciseID)?.name } ?? "Add an exercise"
        var start: Date? = nil
        if let end = restEnd { start = end.addingTimeInterval(-Double(max(restTotal, 1))) }
        return .init(restStart: start, restEnd: restEnd, setsDone: s.completedSets, setsTotal: total, exercise: name)
    }

    func syncLiveActivity() {
        guard profile.liveActivity, let s = active, let state = liveState() else {
            LiveWorkout.endAll()
            return
        }
        LiveWorkout.upsert(session: s, state: state, theme: profile.accent)
    }

    func writeWidgetSnapshot() {
        guard WidgetSnapshot.url != nil else { return }
        let overall = overallScore().map(RankInfo.from)
        let pinned = routines.filter { $0.pinned }.prefix(3).map {
            WidgetRoutine(id: $0.id, name: $0.name, exercises: $0.entries.count)
        }
        let snap = WidgetSnapshot(name: profile.name,
                                  sessionDates: sessions.prefix(400).map { $0.start },
                                  weeklyGoal: profile.weeklyGoal,
                                  overallTitle: overall?.title,
                                  overallColors: overall?.tier.hexColors ?? [],
                                  overallSymbol: overall?.tier.symbol,
                                  overallProgress: overall?.progress ?? 0,
                                  pinned: Array(pinned),
                                  accent: profile.accent.hex.0,
                                  accent2: profile.accent.hex.1,
                                  activeName: active?.name,
                                  activeStart: active?.start)
        guard let data = try? JSONEncoder().encode(snap), data != lastWidgetData, let url = WidgetSnapshot.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            lastWidgetData = data
            WidgetCenter.shared.reloadAllTimelines()
        } catch {}
    }
}

enum LiveWorkout {
    private static var lastState: WorkoutActivityAttributes.ContentState?
    /// Start time of a workout whose activity couldn't be created, so we don't retry on every keystroke.
    private static var failedStart: Date?

    static func upsert(session: WorkoutSession, state: WorkoutActivityAttributes.ContentState, theme: AccentTheme) {
        let all = Activity<WorkoutActivityAttributes>.activities
        let current = all.first { abs($0.attributes.start.timeIntervalSince(session.start)) < 1 }
        for a in all where a.id != current?.id {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        let content = ActivityContent(state: state, staleDate: state.restEnd)
        if let current {
            guard state != lastState else { return }
            lastState = state
            Task { await current.update(content) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled, failedStart != session.start else { return }
            let attrs = WorkoutActivityAttributes(name: session.name, start: session.start,
                                                  accent: theme.hex.0, accent2: theme.hex.1)
            lastState = state
            do {
                _ = try Activity.request(attributes: attrs, content: content, pushType: nil)
            } catch {
                failedStart = session.start
            }
        }
    }

    static func endAll() {
        lastState = nil
        for a in Activity<WorkoutActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
