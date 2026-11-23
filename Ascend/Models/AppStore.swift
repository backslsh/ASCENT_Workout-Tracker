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
    let achievements: [Achievement]
}

struct HistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let sets: [SetEntry]
}

/// A "try this today" suggestion based on the last time an exercise was done.
struct ProgressionHint: Hashable {
    let title: String
    let detail: String
    /// Target values for working sets, in order (the last one repeats for extra sets).
    let targets: [SetEntry]
}

final class AppStore: ObservableObject {
    @Published var profile: Profile { didSet { profileChanged(from: oldValue) } }
    @Published var routines: [Routine] { didSet { scheduleSave() } }
    @Published var sessions: [WorkoutSession] { didSet { recomputeBests(); scheduleSave() } }
    @Published var customExercises: [Exercise] { didSet { rebuildIndex(); scheduleSave() } }
    @Published var active: WorkoutSession? { didSet { scheduleSave(); syncLiveActivity() } }
    @Published var exerciseNotes: [String: String] { didSet { scheduleSave() } }
    @Published var weightLog: [WeightEntry] { didSet { scheduleSave() } }
    @Published var unlocked: [String: Date] { didSet { scheduleSave() } }
    @Published var lastAutoBackup: Date? { didSet { scheduleSave() } }

    @Published var showActive = false
    @Published var restEnd: Date? { didSet { syncLiveActivity() } }
    @Published var restTotal: Int = 90
    @Published var lastSummary: WorkoutSummary?
    @Published private(set) var bests: [String: Best] = [:]
    @Published private(set) var prCount = 0

    private(set) var index: [String: Exercise] = [:]
    private var saveWork: DispatchWorkItem?
    var lastWidgetData: Data?

    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var fileURL: URL { documents.appendingPathComponent("ascend-data.json") }
    static var backupDir: URL { documents.appendingPathComponent("Backups", isDirectory: true) }

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
            exerciseNotes = d.exerciseNotes ?? [:]
            weightLog = (d.weightLog ?? []).sorted { $0.date < $1.date }
            unlocked = d.achievements ?? [:]
            lastAutoBackup = d.lastAutoBackup
        } else {
            profile = Profile()
            routines = Templates.routines
            sessions = []
            customExercises = []
            active = nil
            exerciseNotes = [:]
            weightLog = []
            unlocked = [:]
            lastAutoBackup = nil
        }
        ThemeManager.shared.theme = profile.accent
        Sounds.enabled = profile.sounds
        rebuildIndex()
        recomputeBests()
        if weightLog.isEmpty && profile.onboarded {
            weightLog = [WeightEntry(date: sessions.last?.start ?? Date(), kg: profile.bodyweight)]
        }
        // Record achievements already earned (e.g. after an update) without announcing them.
        _ = refreshAchievements()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.autoBackupIfNeeded()
            self.syncLiveActivity()
            self.writeWidgetSnapshot()
        }
    }

    private func profileChanged(from old: Profile) {
        if profile.accent != old.accent { ThemeManager.shared.theme = profile.accent }
        Sounds.enabled = profile.sounds
        if profile.liveActivity != old.liveActivity { syncLiveActivity() }
        scheduleSave()
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

    /// Whether the exercise fits the user's "My Equipment" list (bodyweight always does).
    func canDo(_ ex: Exercise) -> Bool {
        profile.myEquipment.isEmpty || ex.equipment == .bodyweight || profile.myEquipment.contains(ex.equipment)
    }

    // MARK: Notes

    func note(for id: String) -> String { exerciseNotes[id] ?? "" }

    func setNote(_ text: String, for id: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { exerciseNotes.removeValue(forKey: id) } else { exerciseNotes[id] = t }
    }

    // MARK: Ranks

    func recomputeBests() {
        var d: [String: Best] = [:]
        var prs = 0
        // Oldest first, so we can count how many times a best was beaten.
        for s in sessions.reversed() {
            let bw = s.bodyweight ?? profile.bodyweight
            for e in s.entries {
                guard let ex = index[e.exerciseID] else { continue }
                for set in e.sets where set.done && !set.isWarmup {
                    let p = RankEngine.performance(of: set, exercise: ex, bodyweight: bw)
                    let old = d[ex.id]?.perf ?? 0
                    if p > old + 1e-9 {
                        if old > 0 { prs += 1 }
                        d[ex.id] = Best(perf: p, set: set, date: s.start)
                    }
                }
            }
        }
        bests = d
        prCount = prs
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

    /// Rounded for big numbers (e.g. "4,500 kg").
    func roundWeightText(_ kg: Double) -> String {
        let v = profile.units.display(kg)
        let r = v >= 1000 ? (v / 100).rounded() * 100 : v.rounded()
        return "\(fmtNumber(r)) \(profile.units.rawValue)"
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

    // MARK: Progression hints

    func progressionHint(for entry: ExerciseEntry) -> ProgressionHint? {
        guard let ex = exercise(entry.exerciseID),
              let last = lastSets(for: ex.id)?.filter({ $0.done && !$0.isWarmup }), !last.isEmpty else { return nil }
        let units = profile.units
        switch ex.kind {
        case .weighted:
            guard let top = last.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) }), top.weight > 0 else { return nil }
            let atTop = last.filter { abs($0.weight - top.weight) < 0.01 }
            let minReps = atTop.map { $0.reps }.min() ?? top.reps
            let sameReps = Set(atTop.map { $0.reps }).count == 1
            let shown = (units.display(top.weight) * 2).rounded() / 2
            let lastText = "\(fmtNumber(shown)) × \(minReps)"
            if minReps >= 10 || (minReps <= 5 && sameReps && atTop.count >= 2) {
                let newShown = shown + weightIncrement(ex)
                let reps = minReps >= 10 ? max(6, minReps - 2) : minReps
                let kg = units.toKg(newShown)
                return ProgressionHint(title: "Go up: \(fmtNumber(newShown)) \(units.rawValue) × \(reps)",
                                       detail: "You hit \(lastText) on every top set last time",
                                       targets: [SetEntry(weight: kg, reps: reps)])
            }
            return ProgressionHint(title: "Aim for \(minReps + 1) reps at \(fmtNumber(shown)) \(units.rawValue)",
                                   detail: "Last time: \(lastText). One more rep, then add weight",
                                   targets: [SetEntry(weight: top.weight, reps: minReps + 1)])
        case .reps:
            let best = last.map { $0.reps }.max() ?? 0
            guard best > 0 else { return nil }
            return ProgressionHint(title: "Beat \(best): aim for \(best + 1) reps",
                                   detail: "Add one rep to each set",
                                   targets: last.map { SetEntry(weight: $0.weight, reps: $0.reps + 1) })
        case .timed:
            let best = last.map { $0.seconds }.max() ?? 0
            guard best > 0 else { return nil }
            return ProgressionHint(title: "Hold for \(fmtDuration(Double(best + 5)))",
                                   detail: "Last best: \(fmtDuration(Double(best))). Add 5 seconds",
                                   targets: last.map { SetEntry(weight: $0.weight, seconds: $0.seconds + 5) })
        }
    }

    private func weightIncrement(_ ex: Exercise) -> Double {
        let lower = ex.muscle == .legs || ex.muscle == .glutes || ex.id == "deadlift"
        switch profile.units {
        case .lb:
            if ex.equipment == .barbell || ex.equipment == .machine { return lower ? 10 : 5 }
            return 5
        case .kg:
            if ex.equipment == .barbell || ex.equipment == .machine { return lower ? 5 : 2.5 }
            if ex.equipment == .dumbbell || ex.equipment == .kettlebell { return 2 }
            return 2.5
        }
    }

    func apply(_ hint: ProgressionHint, to entry: inout ExerciseEntry) {
        guard !hint.targets.isEmpty else { return }
        var n = 0
        for i in entry.sets.indices where !entry.sets[i].isWarmup {
            defer { n += 1 }
            guard !entry.sets[i].done else { continue }
            let t = hint.targets[min(n, hint.targets.count - 1)]
            entry.sets[i].weight = t.weight
            entry.sets[i].reps = t.reps
            entry.sets[i].seconds = t.seconds
        }
    }

    // MARK: Stats

    var workoutsThisWeek: Int { TrainingMath.workoutsThisWeek(sessions.map { $0.start }) }

    var weekStreak: Int { TrainingMath.weekStreak(sessions.map { $0.start }) }

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

    func lastTrained(_ g: MuscleGroup) -> Date? {
        sessions.first { s in s.entries.contains { exercise($0.exerciseID)?.muscle == g } }?.start
    }

    func daysSince(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day
    }

    /// Working sets for a muscle group in the last `days` days.
    func recentSets(_ g: MuscleGroup, days: Int = 7) -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return sessions.prefix(while: { $0.start >= cutoff }).reduce(0) { acc, s in
            acc + s.entries.filter { exercise($0.exerciseID)?.muscle == g }
                .reduce(0) { $0 + $1.sets.filter { $0.done && !$0.isWarmup }.count }
        }
    }

    func isHomeSession(_ s: WorkoutSession) -> Bool {
        !s.entries.isEmpty && s.entries.allSatisfy { exercise($0.exerciseID)?.equipment.isHome ?? false }
    }

    // MARK: Achievements

    func achievementValue(_ m: AchievementMetric) -> Double {
        let cal = Calendar.current
        switch m {
        case .workouts: return Double(sessions.count)
        case .longestStreak: return Double(TrainingMath.longestWeekStreak(sessions.map { $0.start }))
        case .totalSets: return Double(sessions.reduce(0) { $0 + $1.completedSets })
        case .maxSessionVolume: return sessions.map { $0.volume }.max() ?? 0
        case .totalVolume: return totalVolume
        case .prs: return Double(prCount)
        case .bestTier: return Double(bests.keys.compactMap { rank($0)?.tier.rawValue }.max() ?? -1)
        case .groupsRanked: return Double(MuscleGroup.allCases.filter { groupScore($0) != nil }.count)
        case .overallTier: return Double(overallScore().map { RankInfo.from(score: $0).tier.rawValue } ?? -1)
        case .homeWorkouts: return Double(sessions.filter(isHomeSession).count)
        case .earlyBird: return Double(sessions.filter { cal.component(.hour, from: $0.start) < 7 }.count)
        case .nightOwl: return Double(sessions.filter { cal.component(.hour, from: $0.start) >= 21 }.count)
        case .weighIns: return Double(weightLog.count)
        case .longestSession: return (sessions.map { $0.duration }.max() ?? 0) / 60
        }
    }

    func achievementProgress(_ a: Achievement) -> Double {
        if unlocked[a.id] != nil { return 1 }
        let v = achievementValue(a.metric)
        if a.metric.display == .tier { return min(1, max(0, v + 1) / (a.goal + 1)) }
        return min(1, max(0, v) / a.goal)
    }

    func achievementProgressText(_ a: Achievement) -> String {
        let v = achievementValue(a.metric)
        switch a.metric.display {
        case .count: return "\(Int(min(v, a.goal)))/\(Int(a.goal))"
        case .weight: return "\(roundWeightText(min(v, a.goal))) / \(roundWeightText(a.goal))"
        case .minutes: return "\(Int(min(v, a.goal)))/\(Int(a.goal)) min"
        case .tier: return v >= 0 ? "Best: \(RankTier(rawValue: Int(v))?.name ?? "—")" : "Unranked"
        }
    }

    func achievementDetail(_ a: Achievement) -> String {
        a.detail.replacingOccurrences(of: "{w}", with: roundWeightText(a.goal))
    }

    /// Unlocks anything newly earned and returns it.
    @discardableResult
    func refreshAchievements() -> [Achievement] {
        var new: [Achievement] = []
        var u = unlocked
        for a in Achievements.all where u[a.id] == nil && achievementValue(a.metric) >= a.goal {
            u[a.id] = Date()
            new.append(a)
        }
        if !new.isEmpty { unlocked = u }
        return new
    }

    // MARK: Bodyweight

    func logWeight(kg: Double, date: Date = Date()) {
        let cal = Calendar.current
        var log = weightLog
        if let i = log.firstIndex(where: { cal.isDate($0.date, inSameDayAs: date) }) {
            log[i].kg = kg
            log[i].date = date
        } else {
            log.append(WeightEntry(date: date, kg: kg))
        }
        log.sort { $0.date < $1.date }
        weightLog = log
        if let latest = log.last, abs(latest.kg - profile.bodyweight) > 0.001 { profile.bodyweight = latest.kg }
        refreshAchievements()
    }

    func deleteWeight(_ id: UUID) {
        weightLog.removeAll { $0.id == id }
        if let latest = weightLog.last { profile.bodyweight = latest.kg }
    }

    /// Logs today's weight if it was edited elsewhere (e.g. Settings).
    func syncWeightLog() {
        guard profile.onboarded else { return }
        if let last = weightLog.last, abs(last.kg - profile.bodyweight) < 0.05 { return }
        logWeight(kg: profile.bodyweight)
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
        var prepared = entries.map { prepare($0) }
        prepared.normalizeSupersets()
        active = WorkoutSession(name: name, routineID: routineID, start: Date(), end: nil,
                                entries: prepared, bodyweight: profile.bodyweight)
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
        s.entries.normalizeSupersets()
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
        let earned = refreshAchievements()
        let summary = WorkoutSummary(session: s, prs: prs, rankUps: ups, achievements: earned)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.lastSummary = summary }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.autoBackupIfNeeded() }
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
        restTotal = max(restTotal + delta, Int(newEnd.timeIntervalSinceNow.rounded(.up)))
        restEnd = newEnd
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
            Sounds.restDone()
        }
    }

    // MARK: Persistence

    func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    func saveNow() {
        if let d = try? JSONEncoder().encode(currentData()) {
            try? d.write(to: Self.fileURL, options: .atomic)
        }
        writeWidgetSnapshot()
    }

    private func currentData() -> AppData {
        AppData(profile: profile, routines: routines, sessions: sessions, customExercises: customExercises, active: active,
                exerciseNotes: exerciseNotes, weightLog: weightLog, achievements: unlocked, lastAutoBackup: lastAutoBackup)
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
        exerciseNotes = d.exerciseNotes ?? [:]
        weightLog = (d.weightLog ?? []).sorted { $0.date < $1.date }
        unlocked = d.achievements ?? [:]
        var p = d.profile
        p.onboarded = true
        profile = p
        active = nil
        refreshAchievements()
        saveNow()
    }

    func resetAll() {
        cancelRest()
        active = nil
        showActive = false
        customExercises = []
        sessions = []
        routines = Templates.routines
        exerciseNotes = [:]
        weightLog = []
        unlocked = [:]
        profile = Profile()
        saveNow()
    }

    // MARK: Automatic backups (Files › On My iPhone › Ascend › Backups)

    @discardableResult
    func autoBackupIfNeeded(force: Bool = false) -> Bool {
        if !force {
            guard profile.autoBackup, !sessions.isEmpty else { return false }
            if let last = lastAutoBackup, Date().timeIntervalSince(last) < 7 * 86400 { return false }
        }
        let fm = FileManager.default
        let dir = Self.backupDir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let file = dir.appendingPathComponent("Ascend-Backup-\(f.string(from: Date())).json")
        do { try exportData().write(to: file, options: .atomic) } catch { return false }
        lastAutoBackup = Date()
        // Keep the 6 most recent.
        if let files = try? fm.contentsOfDirectory(atPath: dir.path) {
            let backups = files.filter { $0.hasPrefix("Ascend-Backup-") && $0.hasSuffix(".json") }.sorted(by: >)
            for name in backups.dropFirst(6) { try? fm.removeItem(at: dir.appendingPathComponent(name)) }
        }
        return true
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
