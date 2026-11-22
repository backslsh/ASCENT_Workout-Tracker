import SwiftUI
import UserNotifications

struct Best: Hashable {
    var perf: Double
    var set: SetEntry
    var date: Date
}

struct RankUp: Identifiable, Hashable {
    let id = UUID()
    let exerciseID: String
    let from: RankInfo?
    let to: RankInfo
}

struct PRItem: Identifiable, Hashable {
    let id = UUID()
    let exerciseID: String
    let set: SetEntry
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let session: WorkoutSession
    let prs: [PRItem]
    let rankUps: [RankUp]
}

struct HistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let sets: [SetEntry]
}

final class AppStore: ObservableObject {
    @Published var profile: Profile { didSet { scheduleSave() } }
    @Published var routines: [Routine] { didSet { scheduleSave() } }
    @Published var sessions: [WorkoutSession] { didSet { recomputeBests(); scheduleSave() } }
    @Published var customExercises: [Exercise] { didSet { rebuildIndex(); scheduleSave() } }
    @Published var active: WorkoutSession? { didSet { scheduleSave() } }

    @Published var showActive = false
    @Published var restEnd: Date?
    @Published var restTotal: Int = 90
    @Published var lastSummary: WorkoutSummary?
    @Published private(set) var bests: [String: Best] = [:]

    private(set) var index: [String: Exercise] = [:]
    private var saveWork: DispatchWorkItem?

    static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ascend-data.json")
    }

    init() {
        let url = Self.fileURL
        var loaded: AppData?
        if let data = try? Data(contentsOf: url) {
            loaded = try? JSONDecoder().decode(AppData.self, from: data)
            if loaded == nil {
                // Never silently overwrite data we couldn't read — keep a copy.
                let backup = url.deletingLastPathComponent()
                    .appendingPathComponent("ascend-data-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? data.write(to: backup)
            }
        }
        if let d = loaded {
            profile = d.profile
            routines = d.routines
            sessions = d.sessions.sorted { $0.start > $1.start }
            customExercises = d.customExercises
            active = d.active
        } else {
            profile = Profile()
            routines = Templates.routines
            sessions = []
            customExercises = []
            active = nil
        }
        rebuildIndex()
        recomputeBests()
    }

    // MARK: Exercises

    var allExercises: [Exercise] { ExerciseLibrary.all + customExercises }

    func exercise(_ id: String) -> Exercise? { index[id] }

    func exercises(in g: MuscleGroup) -> [Exercise] { allExercises.filter { $0.muscle == g } }

    private func rebuildIndex() {
        var d: [String: Exercise] = [:]
        for e in allExercises { d[e.id] = e }
        index = d
    }

    func addCustom(name: String, muscle: MuscleGroup, kind: ExerciseKind, equipment: Equipment) -> Exercise {
        let ex = Exercise(id: "custom_" + UUID().uuidString, name: name, muscle: muscle, kind: kind,
                          equipment: equipment, elite: ExerciseLibrary.defaultElite(kind: kind, equipment: equipment),
                          isCustom: true)
        customExercises.append(ex)
        return ex
    }

    func deleteCustom(_ id: String) {
        customExercises.removeAll { $0.id == id }
        profile.showcase.removeAll { $0 == id }
    }

    func muscles(of entries: [ExerciseEntry]) -> [MuscleGroup] {
        var out: [MuscleGroup] = []
        for e in entries {
            if let m = exercise(e.exerciseID)?.muscle, !out.contains(m) { out.append(m) }
        }
        return out
    }

    // MARK: Ranks

    func recomputeBests() {
        var d: [String: Best] = [:]
        for s in sessions {
            let bw = s.bodyweight ?? profile.bodyweight
            for e in s.entries {
                guard let ex = index[e.exerciseID] else { continue }
                for set in e.sets where set.done && !set.isWarmup {
                    let p = RankEngine.performance(of: set, exercise: ex, bodyweight: bw)
                    if p > (d[ex.id]?.perf ?? 0) { d[ex.id] = Best(perf: p, set: set, date: s.start) }
                }
            }
        }
        bests = d
    }

    func score(_ id: String) -> Double? {
        guard let b = bests[id], let ex = index[id], b.perf > 0 else { return nil }
        return RankEngine.score(perf: b.perf, exercise: ex, sex: profile.sex)
    }

    func rank(_ id: String) -> RankInfo? { score(id).map(RankInfo.from) }

    /// A muscle group's rank is its best lift's rank.
    func groupScore(_ g: MuscleGroup) -> Double? {
        exercises(in: g).compactMap { score($0.id) }.max()
    }

    func groupRank(_ g: MuscleGroup) -> RankInfo? { groupScore(g).map(RankInfo.from) }

    func overallScore() -> Double? {
        let s = MuscleGroup.allCases.compactMap { groupScore($0) }
        guard !s.isEmpty else { return nil }
        return s.reduce(0, +) / Double(s.count)
    }

    func requirementText(score: Double, exercise ex: Exercise) -> String {
        let perf = RankEngine.perfNeeded(score: score, exercise: ex, sex: profile.sex)
        switch ex.kind {
        case .weighted: return "\(weightText(perf * profile.bodyweight)) 1RM"
        case .reps: return "\(Int(perf.rounded(.up))) reps"
        case .timed: return fmtDuration(perf.rounded(.up))
        }
    }

    func nextRequirement(_ id: String) -> String? {
        guard let ex = exercise(id) else { return nil }
        guard let r = rank(id) else { return "Log a set to get ranked" }
        guard let next = r.nextThreshold, let title = r.nextTitle else { return "Maxed out — legendary" }
        return "\(title) at \(requirementText(score: next, exercise: ex))"
    }

    // MARK: Display

    func weightText(_ kg: Double) -> String {
        "\(fmtNumber(profile.units.display(kg))) \(profile.units.rawValue)"
    }

    func setText(_ s: SetEntry, _ ex: Exercise) -> String {
        let added = s.weight > 0 ? " +\(fmtNumber(profile.units.display(s.weight)))" : ""
        switch ex.kind {
        case .weighted: return "\(fmtNumber(profile.units.display(s.weight))) × \(s.reps)"
        case .reps: return "\(s.reps) reps\(added)"
        case .timed: return "\(fmtDuration(Double(s.seconds)))\(added)"
        }
    }

    func bestText(_ id: String) -> String {
        guard let b = bests[id], let ex = exercise(id) else { return "No sets yet" }
        return setText(b.set, ex)
    }

    func metricValue(_ s: SetEntry, _ ex: Exercise) -> Double {
        switch ex.kind {
        case .weighted: return profile.units.display(RankEngine.e1RM(weight: s.weight, reps: s.reps))
        case .reps: return Double(s.reps)
        case .timed: return Double(s.seconds)
        }
    }

    func metricLabel(_ ex: Exercise) -> String {
        switch ex.kind {
        case .weighted: return "Est. 1RM (\(profile.units.rawValue))"
        case .reps: return "Best reps"
        case .timed: return "Best hold (sec)"
        }
    }

    func history(for id: String) -> [HistoryPoint] {
        guard let ex = exercise(id) else { return [] }
        return sessions.compactMap { s -> HistoryPoint? in
            let sets = s.entries.filter { $0.exerciseID == id }.flatMap { $0.sets }.filter { $0.done && !$0.isWarmup }
            guard !sets.isEmpty else { return nil }
            let v = sets.map { metricValue($0, ex) }.max() ?? 0
            return HistoryPoint(date: s.start, value: v, sets: sets)
        }
        .sorted { $0.date < $1.date }
    }

    func lastSets(for exerciseID: String) -> [SetEntry]? {
        for s in sessions {
            if let e = s.entries.first(where: { $0.exerciseID == exerciseID }) { return e.sets }
        }
        return nil
    }

    // MARK: Stats

    var workoutsThisWeek: Int {
        let cal = Calendar.current
        return sessions.filter { cal.isDate($0.start, equalTo: Date(), toGranularity: .weekOfYear) }.count
    }

    var weekStreak: Int {
        let cal = Calendar.current
        guard var week = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        let starts = Set(sessions.compactMap { cal.dateInterval(of: .weekOfYear, for: $0.start)?.start })
        if !starts.contains(week) { week = cal.date(byAdding: .weekOfYear, value: -1, to: week) ?? week }
        var streak = 0
        while starts.contains(week) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = prev
        }
        return streak
    }

    var totalVolume: Double { sessions.reduce(0) { $0 + $1.volume } }

    var recentSessions: [WorkoutSession] {
        var seen = Set<String>()
        var out: [WorkoutSession] = []
        for s in sessions where !seen.contains(s.name) {
            seen.insert(s.name)
            out.append(s)
            if out.count == 5 { break }
        }
        return out
    }

    // MARK: Routines

    func upsert(_ r: Routine) {
        if let i = routines.firstIndex(where: { $0.id == r.id }) { routines[i] = r } else { routines.insert(r, at: 0) }
    }

    func deleteRoutine(_ id: UUID) { routines.removeAll { $0.id == id } }

    func togglePin(_ id: UUID) {
        guard let i = routines.firstIndex(where: { $0.id == id }) else { return }
        routines[i].pinned.toggle()
    }

    func duplicate(_ r: Routine) {
        var c = r
        c.id = UUID()
        c.name = r.name + " Copy"
        c.pinned = false
        c.created = Date()
        routines.insert(c, at: 0)
    }

    func saveAsRoutine(_ s: WorkoutSession) {
        let entries = s.entries.map { e -> ExerciseEntry in
            var e = e
            e.id = UUID()
            e.sets = e.sets.map { var x = $0; x.id = UUID(); x.done = false; return x }
            return e
        }
        routines.insert(Routine(name: s.name, entries: entries), at: 0)
    }

    func toggleShowcase(_ id: String) {
        if let i = profile.showcase.firstIndex(of: id) {
            profile.showcase.remove(at: i)
        } else if profile.showcase.count < 5 {
            profile.showcase.append(id)
        }
    }

    // MARK: Workout lifecycle

    func defaultSet(for ex: Exercise) -> SetEntry {
        switch ex.kind {
        case .weighted: return SetEntry(reps: 10)
        case .reps: return SetEntry(reps: 12)
        case .timed: return SetEntry(seconds: 45)
        }
    }

    func makeEntry(for ex: Exercise) -> ExerciseEntry {
        let prev = (lastSets(for: ex.id) ?? []).filter { !$0.isWarmup }
        let sets: [SetEntry]
        if !prev.isEmpty {
            sets = prev.map { SetEntry(weight: $0.weight, reps: $0.reps, seconds: $0.seconds) }
        } else {
            sets = (0..<3).map { _ in defaultSet(for: ex) }
        }
        let rest = ex.kind == .weighted ? profile.defaultRest : min(profile.defaultRest, 60)
        return ExerciseEntry(exerciseID: ex.id, sets: sets, restSeconds: rest)
    }

    private func prepare(_ entry: ExerciseEntry) -> ExerciseEntry {
        var e = entry
        e.id = UUID()
        let prev = (lastSets(for: e.exerciseID) ?? []).filter { !$0.isWarmup }
        let isWeighted = exercise(e.exerciseID)?.kind == .weighted
        let original = e.sets
        e.sets = original.enumerated().map { (i: Int, s: SetEntry) -> SetEntry in
            var x = s
            x.id = UUID()
            x.done = false
            if x.weight == 0, !prev.isEmpty, isWeighted {
                x.weight = prev[min(i, prev.count - 1)].weight
            }
            return x
        }
        return e
    }

    func startWorkout(name: String, entries: [ExerciseEntry], routineID: UUID?) {
        if active != nil { showActive = true; return }
        active = WorkoutSession(name: name, routineID: routineID, start: Date(), end: nil,
                                entries: entries.map { prepare($0) }, bodyweight: profile.bodyweight)
        if let rid = routineID, let i = routines.firstIndex(where: { $0.id == rid }) {
            routines[i].lastUsed = Date()
        }
        Haptics.medium()
        showActive = true
    }

    func startWorkout(_ r: Routine) { startWorkout(name: r.name, entries: r.entries, routineID: r.id) }

    func startEmpty() {
        let h = Calendar.current.component(.hour, from: Date())
        let name = h < 12 ? "Morning Workout" : (h < 17 ? "Afternoon Workout" : "Evening Workout")
        startWorkout(name: name, entries: [], routineID: nil)
    }

    func repeatSession(_ s: WorkoutSession) {
        startWorkout(name: s.name, entries: s.entries, routineID: s.routineID)
    }

    func finishWorkout() {
        guard var s = active else { return }
        s.entries = s.entries.compactMap { e in
            var e = e
            e.sets = e.sets.filter { $0.done }
            return e.sets.isEmpty ? nil : e
        }
        s.end = Date()
        cancelRest()
        showActive = false
        active = nil
        guard !s.entries.isEmpty else { return }

        let ids = Array(Set(s.entries.map { $0.exerciseID })).sorted()
        var beforeRank: [String: RankInfo] = [:]
        var beforePerf: [String: Double] = [:]
        for id in ids {
            if let r = rank(id) { beforeRank[id] = r }
            beforePerf[id] = bests[id]?.perf ?? 0
        }

        sessions.insert(s, at: 0)

        var prs: [PRItem] = []
        var ups: [RankUp] = []
        for id in ids {
            let old = beforePerf[id] ?? 0
            if let b = bests[id], old > 0, b.perf > old + 1e-9 {
                prs.append(PRItem(exerciseID: id, set: b.set))
            }
            if let after = rank(id) {
                let before = beforeRank[id]
                if before == nil || after.ordinal > (before?.ordinal ?? -1) {
                    ups.append(RankUp(exerciseID: id, from: before, to: after))
                }
            }
        }
        let summary = WorkoutSummary(session: s, prs: prs, rankUps: ups)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.lastSummary = summary }
    }

    func discardWorkout() {
        cancelRest()
        showActive = false
        active = nil
    }

    func deleteSession(_ id: UUID) { sessions.removeAll { $0.id == id } }

    // MARK: Rest timer

    func startRest(_ seconds: Int) {
        guard seconds > 0 else { return }
        restTotal = seconds
        withAnimation(Theme.spring) { restEnd = Date().addingTimeInterval(TimeInterval(seconds)) }
        if profile.restNotifications { Notifier.scheduleRest(after: TimeInterval(seconds)) }
    }

    func adjustRest(_ delta: Int) {
        guard let end = restEnd else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(delta))
        if newEnd <= Date().addingTimeInterval(1) { cancelRest(); return }
        restEnd = newEnd
        restTotal = max(restTotal + delta, Int(newEnd.timeIntervalSinceNow.rounded(.up)))
        if profile.restNotifications { Notifier.scheduleRest(after: newEnd.timeIntervalSinceNow) }
        Haptics.tap()
    }

    func cancelRest() {
        withAnimation(Theme.spring) { restEnd = nil }
        Notifier.cancelRest()
    }

    func tick() {
        if let end = restEnd, Date() >= end {
            withAnimation(Theme.spring) { restEnd = nil }
            Haptics.success()
        }
    }

    // MARK: Persistence

    private func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    func saveNow() {
        if let d = try? JSONEncoder().encode(currentData()) {
            try? d.write(to: Self.fileURL, options: .atomic)
        }
    }

    private func currentData() -> AppData {
        AppData(profile: profile, routines: routines, sessions: sessions, customExercises: customExercises, active: active)
    }

    func exportData() -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(currentData())) ?? Data()
    }

    func importData(_ data: Data) throws {
        let d = try JSONDecoder().decode(AppData.self, from: data)
        customExercises = d.customExercises
        routines = d.routines
        sessions = d.sessions.sorted { $0.start > $1.start }
        var p = d.profile
        p.onboarded = true
        profile = p
        active = nil
        saveNow()
    }

    func resetAll() {
        cancelRest()
        active = nil
        showActive = false
        customExercises = []
        sessions = []
        routines = Templates.routines
        profile = Profile()
        saveNow()
    }
}

// MARK: - Local notifications (no paid developer account required)

enum Notifier {
    static func request() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func scheduleRest(after seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["rest"])
        let content = UNMutableNotificationContent()
        content.title = "Rest's over"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: "rest", content: content, trigger: trigger))
    }

    static func cancelRest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest"])
    }
}
