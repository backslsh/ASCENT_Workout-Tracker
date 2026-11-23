import SwiftUI
import Charts

struct RanksView: View {
    @EnvironmentObject var store: AppStore
    @State private var showInfo = false

    private var sortedGroups: [MuscleGroup] {
        MuscleGroup.allCases.sorted { (store.groupScore($0) ?? -1) > (store.groupScore($1) ?? -1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "Ranks", subtitle: "Highest to lowest") {
                        HStack(spacing: 10) {
                            ShareRankButton(card: overallCard)
                            GlassIconButton(symbol: "questionmark") { showInfo = true }
                        }
                    }
                    OverallRankCard()
                    MuscleHeatmapCard()
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Array(sortedGroups.enumerated()), id: \.element) { i, g in
                            NavigationLink(value: g) {
                                MuscleTile(group: g, place: i + 1)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    if !store.sessions.isEmpty {
                        BalanceCard()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MuscleGroup.self) { MuscleDetailView(group: $0) }
            .navigationDestination(for: ExerciseRoute.self) { ExerciseDetailView(exerciseID: $0.id) }
            .sheet(isPresented: $showInfo) { RankLadderSheet().environmentObject(store) }
        }
    }

    private var overallCard: RankShareCard {
        let ranked = MuscleGroup.allCases.filter { store.groupScore($0) != nil }.count
        let top = sortedGroups.first.flatMap { g in store.groupRank(g).map { _ in g.name } } ?? "—"
        return RankShareCard(title: "Overall Rank",
                             subtitle: "\(ranked)/\(MuscleGroup.allCases.count) muscle groups ranked",
                             rank: store.overallScore().map(RankInfo.from),
                             name: store.profile.name,
                             stats: [("\(store.sessions.count)", "WORKOUTS"),
                                     ("\(store.weekStreak) wk", "STREAK"),
                                     (top, "BEST GROUP")])
    }
}

struct OverallRankCard: View {
    @EnvironmentObject var store: AppStore
    @State private var spin = 0.0
    @State private var appeared = false

    var body: some View {
        let r = store.overallScore().map(RankInfo.from)
        let ranked = MuscleGroup.allCases.filter { store.groupScore($0) != nil }.count
        let nextPart: String = r?.nextTitle.map { " · next: \($0)" } ?? ""
        let caption: String = r == nil
            ? "Finish a workout to earn your first rank."
            : "\(ranked)/\(MuscleGroup.allCases.count) groups ranked\(nextPart)"
        HStack(spacing: 18) {
            Button {
                Haptics.medium()
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) { spin += 360 }
            } label: {
                RankBadge(rank: r, size: 86)
                    .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text("OVERALL").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.textTertiary)
                Text(r?.title ?? "Unranked")
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundStyle(LinearGradient(colors: r?.tier.colors ?? [Color.white, Color.gray], startPoint: .leading, endPoint: .trailing))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                ProgressBar(value: r?.progress ?? 0, colors: r?.tier.colors ?? [Theme.accent, Theme.accent2], height: 7)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card(padding: 18)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { appeared = true } }
    }
}

struct MuscleTile: View {
    @EnvironmentObject var store: AppStore
    let group: MuscleGroup
    let place: Int

    var body: some View {
        let r = store.groupRank(group)
        let exercises = store.exercises(in: group)
        let rankedCount = exercises.filter { store.score($0.id) != nil }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                MuscleIcon(group: group, size: 36)
                Spacer()
                RankBadge(rank: r, size: 38)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if r != nil {
                        Text("#\(place)").font(.caption.weight(.heavy)).foregroundStyle(Theme.textTertiary)
                    }
                    Text(group.name).font(.headline).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(r?.title ?? "Unranked")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(r?.color ?? Theme.textTertiary)
            }
            ProgressBar(value: r?.progress ?? 0, colors: r?.tier.colors ?? [group.color, group.color], height: 5)
            Text("\(rankedCount)/\(exercises.count) lifts ranked")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .card(padding: 14)
        .opacity(r == nil ? 0.7 : 1)
    }
}

// MARK: - Muscle group detail

struct MuscleDetailView: View {
    @EnvironmentObject var store: AppStore
    let group: MuscleGroup

    private var sorted: [Exercise] {
        store.exercises(in: group).sorted {
            let a = store.score($0.id) ?? -1, b = store.score($1.id) ?? -1
            return a == b ? $0.name < $1.name : a > b
        }
    }

    var body: some View {
        let r = store.groupRank(group)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(group.color.opacity(0.18)).frame(width: 120, height: 120).blur(radius: 30)
                        RankBadge(rank: r, size: 92)
                    }
                    HStack(spacing: 8) {
                        MuscleIcon(group: group, size: 28)
                        Text(group.name).font(.title2.weight(.bold))
                    }
                    Text(r?.title ?? "Unranked")
                        .font(.headline)
                        .foregroundStyle(r?.color ?? Theme.textTertiary)
                    ProgressBar(value: r?.progress ?? 0, colors: r?.tier.colors ?? [group.color, group.color])
                        .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                Text("Group rank = your best-ranked lift in this group.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)

                VStack(spacing: 10) {
                    ForEach(sorted) { ex in
                        NavigationLink(value: ExerciseRoute(id: ex.id)) {
                            ExerciseRankRow(exercise: ex)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ExerciseRankRow: View {
    @EnvironmentObject var store: AppStore
    let exercise: Exercise

    var body: some View {
        let r = store.rank(exercise.id)
        HStack(spacing: 14) {
            RankBadge(rank: r, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                    Text(r?.title ?? "Unranked").font(.caption.weight(.bold)).foregroundStyle(r?.color ?? Theme.textTertiary)
                }
                ProgressBar(value: r?.progress ?? 0, colors: r?.tier.colors ?? [Theme.textTertiary, Theme.textTertiary], height: 5)
                HStack {
                    Text(store.bests[exercise.id] == nil ? exercise.equipment.name : store.bestText(exercise.id))
                    Spacer()
                    Text(store.nextRequirement(exercise.id) ?? "")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .card(padding: 12, radius: 18)
        .opacity(r == nil ? 0.65 : 1)
    }
}

// MARK: - Exercise detail

struct ExerciseDetailView: View {
    @EnvironmentObject var store: AppStore
    let exerciseID: String
    @State private var spin = 0.0

    var body: some View {
        let ex = store.exercise(exerciseID) ?? .unknown
        let r = store.rank(exerciseID)
        let points = store.history(for: exerciseID)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero(ex, r)
                if let b = store.bests[exerciseID] {
                    HStack(spacing: 10) {
                        StatTile(value: store.setText(b.set, ex), label: "Best set", symbol: "trophy.fill", color: RankTier.gold.colors[0])
                        if ex.kind == .weighted {
                            StatTile(value: store.weightText(RankEngine.e1RM(weight: b.set.weight, reps: b.set.reps)),
                                     label: "Est. 1RM", symbol: "scalemass.fill", color: Theme.accent2)
                        } else {
                            StatTile(value: "\(points.count)", label: "Sessions", symbol: "calendar", color: Theme.accent2)
                        }
                    }
                }
                ladder(ex, r)
                chart(ex, points)
                recent(ex, points)
                showcaseButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle(ex.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareRankButton(card: shareCard(ex, r, points), glass: false)
            }
        }
    }

    private func shareCard(_ ex: Exercise, _ r: RankInfo?, _ points: [HistoryPoint]) -> RankShareCard {
        var stats: [(String, String)] = []
        if let b = store.bests[exerciseID] {
            stats.append((store.setText(b.set, ex), "BEST SET"))
            if ex.kind == .weighted {
                stats.append((store.weightText(RankEngine.e1RM(weight: b.set.weight, reps: b.set.reps)), "EST. 1RM"))
            }
        }
        stats.append(("\(points.count)", "SESSIONS"))
        return RankShareCard(title: ex.name, subtitle: "\(ex.muscle.name) · \(ex.equipment.name)",
                             rank: r, name: store.profile.name, stats: stats)
    }

    private func hero(_ ex: Exercise, _ r: RankInfo?) -> some View {
        VStack(spacing: 10) {
            Button {
                Haptics.medium()
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) { spin += 360 }
            } label: {
                ZStack {
                    Circle().fill((r?.color ?? ex.muscle.color).opacity(0.2)).frame(width: 130, height: 130).blur(radius: 34)
                    RankBadge(rank: r, size: 104)
                        .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
                }
            }
            .buttonStyle(.plain)
            Text(r?.title ?? "Unranked")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(LinearGradient(colors: r?.tier.colors ?? [Color.white, Color.gray], startPoint: .leading, endPoint: .trailing))
            HStack(spacing: 6) {
                MuscleIcon(group: ex.muscle, size: 22)
                Text("\(ex.muscle.name) · \(ex.equipment.name) · \(ex.kind.label)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            ProgressBar(value: r?.progress ?? 0, colors: r?.tier.colors ?? [Theme.accent, Theme.accent2])
                .frame(maxWidth: 240)
            if let next = store.nextRequirement(exerciseID) {
                Text(next).font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func ladder(_ ex: Exercise, _ r: RankInfo?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Rank Ladder")
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(RankTier.allCases) { t in
                            let reached = r != nil && (r?.tier ?? .iron) >= t
                            let current = r?.tier == t
                            VStack(spacing: 6) {
                                RankBadge(rank: .display(t), size: current ? 50 : 40)
                                    .opacity(reached ? 1 : 0.3)
                                    .frame(height: 56)
                                Text(t.name).font(.caption2.weight(.bold)).foregroundStyle(reached ? t.colors[0] : Theme.textTertiary)
                                Text(t == .iron ? "Any set" : store.requirementText(score: t.threshold, exercise: ex))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.textTertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(width: 82)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(current ? t.colors[0].opacity(0.12) : Color.clear))
                            .id(t)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
                .onAppear { if let t = r?.tier { proxy.scrollTo(t, anchor: .center) } }
            }
        }
    }

    @ViewBuilder
    private func chart(_ ex: Exercise, _ points: [HistoryPoint]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Progress")
            if points.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.metricLabel(ex)).font(.caption).foregroundStyle(Theme.textSecondary)
                    Chart(points) { p in
                        AreaMark(x: .value("Date", p.date), y: .value("Value", p.value))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0.0)],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Date", p.date), y: .value("Value", p.value))
                            .foregroundStyle(Theme.accentGradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                            .foregroundStyle(Theme.accent2)
                            .symbolSize(28)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)
                }
                .card()
            } else {
                Text(points.isEmpty ? "Log this exercise to start tracking progress." : "Log one more session to see your trend.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        }
    }

    @ViewBuilder
    private func recent(_ ex: Exercise, _ points: [HistoryPoint]) -> some View {
        if !points.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Recent Sessions")
                VStack(spacing: 0) {
                    ForEach(Array(points.reversed().prefix(6).enumerated()), id: \.element.id) { i, p in
                        HStack(alignment: .top) {
                            Text(p.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 64, alignment: .leading)
                            Text(p.sets.map { store.setText($0, ex) }.joined(separator: "   "))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        if i < min(points.count, 6) - 1 { Divider().overlay(Theme.stroke) }
                    }
                }
                .card(padding: 0)
            }
        }
    }

    private var showcaseButton: some View {
        let on = store.profile.showcase.contains(exerciseID)
        let full = store.profile.showcase.count >= 5
        return SecondaryButton(title: on ? "Remove from Showcase" : (full ? "Showcase full (5/5)" : "Add to Profile Showcase"),
                               symbol: on ? "star.slash" : "star.fill",
                               tint: on ? Theme.textSecondary : Theme.accent) {
            withAnimation(Theme.snappy) { store.toggleShowcase(exerciseID) }
        }
        .disabled(!on && full)
    }
}

// MARK: - Explainer

struct RankLadderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Every exercise is scored against strength standards relative to your bodyweight.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 8) {
                        bullet("scalemass.fill", "Weighted lifts use your estimated 1-rep max (from weight × reps).")
                        bullet("figure.core.training", "Bodyweight moves use reps — added weight boosts the score.")
                        bullet("timer", "Holds like planks use time.")
                        bullet("square.stack.3d.up.fill", "Each rank has three divisions: III → II → I.")
                        bullet("flame", "Warm-up sets don't count toward ranks.")
                    }
                    .card()

                    VStack(spacing: 0) {
                        ForEach(RankTier.allCases.reversed()) { t in
                            HStack(spacing: 14) {
                                RankBadge(rank: .display(t), size: 36)
                                Text(t.name).font(.headline).foregroundStyle(t.colors[0])
                                Spacer()
                                Text("\(Int(t.threshold * 100))% of elite")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .card(padding: 0)
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("How Ranks Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
        }
        .presentationDetents([.large])
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 22)
            Text(text).font(.subheadline)
        }
    }
}
