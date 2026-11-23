import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @Binding var tab: AppTab
    @State private var showSettings = false
    @State private var showShowcasePicker = false

    private var pinned: [Routine] { store.routines.filter { $0.pinned } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenHeader(title: "Profile", subtitle: Date().formatted(.dateTime.weekday(.wide).month().day())) {
                        GlassIconButton(symbol: "gearshape.fill") { showSettings = true }
                    }
                    IdentityCard()
                    statsRow
                    progressRow
                    showcaseSection
                    quickStartSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ExerciseRoute.self) { ExerciseDetailView(exerciseID: $0.id) }
            .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
            .sheet(isPresented: $showShowcasePicker) { ShowcasePicker().environmentObject(store) }
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(store.sessions.count)", label: "Workouts", symbol: "flame.fill", color: Theme.warning)
            StatTile(value: "\(store.weekStreak) wk", label: "Streak", symbol: "bolt.heart.fill", color: Theme.danger)
            WeeklyGoalTile(done: store.workoutsThisWeek, goal: store.profile.weeklyGoal)
        }
    }

    private var progressRow: some View {
        let unlockedCount = Achievements.all.filter { store.unlocked[$0.id] != nil }.count
        let recent = Achievements.all
            .compactMap { a -> (Achievement, Date)? in
                guard let d = store.unlocked[a.id] else { return nil }
                return (a, d)
            }
            .max { $0.1 < $1.1 }?.0
        let log = store.weightLog
        let trend: String = {
            guard log.count >= 2, let last = log.last else { return "Tap to log" }
            let d = store.profile.units.display(last.kg - log[log.count - 2].kg)
            if abs(d) < 0.05 { return "No change" }
            return "\(d > 0 ? "▲" : "▼") \(fmtNumber(abs(d))) \(store.profile.units.rawValue)"
        }()
        return HStack(spacing: 10) {
            NavigationLink { AchievementsView() } label: {
                ProgressLinkTile(value: "\(unlockedCount)/\(Achievements.all.count)",
                                 label: recent?.title ?? "Achievements",
                                 symbol: recent?.symbol ?? "rosette",
                                 color: recent?.color ?? RankTier.gold.colors[0])
            }
            .buttonStyle(.pressable)
            NavigationLink { BodyweightView() } label: {
                ProgressLinkTile(value: store.weightText(store.profile.bodyweight), label: trend,
                                 symbol: "scalemass.fill", color: Theme.accent2)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: Showcase

    private var showcaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Showcase", actionTitle: "Edit") { showShowcasePicker = true }
            if store.profile.showcase.isEmpty {
                Button { showShowcasePicker = true } label: {
                    HStack(spacing: 14) {
                        RankBadge(rank: nil, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Show off your best lifts").font(.headline).foregroundStyle(.white)
                            Text("Pick up to 5 exercises to display their rank.").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                    }
                    .card()
                }
                .buttonStyle(.pressable)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.profile.showcase, id: \.self) { id in
                            if let ex = store.exercise(id) {
                                NavigationLink(value: ExerciseRoute(id: id)) {
                                    ShowcaseCard(exercise: ex, rank: store.rank(id), best: store.bestText(id))
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, -20)
            }
        }
    }

    // MARK: Quick start

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Start", actionTitle: "All routines") {
                withAnimation(Theme.snappy) { tab = .workout }
            }
            Button { store.startEmpty() } label: {
                HStack(spacing: 12) {
                    Image(systemName: store.active == nil ? "bolt.fill" : "play.fill")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                    Text(store.active == nil ? "Start Empty Workout" : "Resume Workout").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.accentGradient))
                .shadow(color: Theme.accent.opacity(0.35), radius: 14, y: 6)
            }
            .buttonStyle(.pressable)

            if !pinned.isEmpty {
                Label("Pinned", systemImage: "pin.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(pinned) { r in RoutineQuickCard(routine: r) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -20)
            }

            Label("Recent", systemImage: "clock.arrow.circlepath").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            if store.recentSessions.isEmpty {
                Text("Your recent workouts will show up here for one-tap repeats.")
                    .font(.subheadline).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.recentSessions.enumerated()), id: \.element.id) { i, s in
                        RecentRow(session: s)
                        if i < store.recentSessions.count - 1 { Divider().overlay(Theme.stroke).padding(.leading, 16) }
                    }
                }
                .card(padding: 0)
            }
        }
    }
}

// MARK: - Pieces

struct ProgressLinkTile: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12, radius: 18)
    }
}

struct IdentityCard: View {
    @EnvironmentObject var store: AppStore
    @State private var spin = 0.0

    var body: some View {
        let overall = store.overallScore().map(RankInfo.from)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Avatar(name: store.profile.name, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.profile.name.isEmpty ? "Athlete" : store.profile.name)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        InfoPill(symbol: "birthday.cake.fill", text: "\(store.profile.age)")
                        InfoPill(symbol: "scalemass.fill", text: store.weightText(store.profile.bodyweight))
                    }
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.medium()
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.65)) { spin += 360 }
                } label: {
                    RankBadge(rank: overall, size: 58)
                        .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Rank").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(overall?.title ?? "Unranked")
                        .fontWeight(.bold)
                        .foregroundStyle(overall?.color ?? Theme.textTertiary)
                }
                .font(.subheadline)
                ProgressBar(value: overall?.progress ?? 0, colors: overall?.tier.colors ?? [Theme.accent, Theme.accent2])
            }
        }
        .card()
    }
}

struct WeeklyGoalTile: View {
    let done: Int
    let goal: Int
    var body: some View {
        let p = goal > 0 ? min(1, Double(done) / Double(goal)) : 0
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                Circle().trim(from: 0, to: p)
                    .stroke(Theme.success, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 17, height: 17)
            .animation(Theme.spring, value: p)
            Text("\(done)/\(goal)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .contentTransition(.numericText())
            Text("This week").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, radius: 18)
    }
}

struct ShowcaseCard: View {
    let exercise: Exercise
    let rank: RankInfo?
    let best: String
    var body: some View {
        VStack(spacing: 8) {
            RankBadge(rank: rank, size: 52)
            Text(rank?.title ?? "Unranked")
                .font(.caption.weight(.bold))
                .foregroundStyle(rank?.color ?? Theme.textTertiary)
            Text(exercise.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 34)
            Text(best).font(.caption2).foregroundStyle(Theme.textSecondary).lineLimit(1)
        }
        .frame(width: 120)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .card(padding: 0)
    }
}

struct RoutineQuickCard: View {
    @EnvironmentObject var store: AppStore
    let routine: Routine
    var body: some View {
        Button { store.startWorkout(routine) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MuscleStack(groups: store.muscles(of: routine.entries))
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.accentGradient))
                }
                Spacer(minLength: 0)
                Text(routine.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(routine.entries.count) exercises")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 168, height: 124, alignment: .topLeading)
            .card(padding: 14)
        }
        .buttonStyle(.pressable)
    }
}

struct RecentRow: View {
    @EnvironmentObject var store: AppStore
    let session: WorkoutSession
    var body: some View {
        HStack(spacing: 12) {
            MuscleStack(groups: store.muscles(of: session.entries), size: 24)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(session.start.formatted(.relative(presentation: .named))) · \(fmtShortDuration(session.duration))")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button { store.repeatSession(session) } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.accent.opacity(0.15)))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct ShowcasePicker: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var items: [Exercise] {
        store.allExercises
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { (store.score($0.id) ?? -1, $1.name) > (store.score($1.id) ?? -1, $0.name) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { ex in
                        let selected = store.profile.showcase.contains(ex.id)
                        Button {
                            if !selected && store.profile.showcase.count >= 5 { Haptics.warning(); return }
                            Haptics.select()
                            withAnimation(Theme.snappy) { store.toggleShowcase(ex.id) }
                        } label: {
                            HStack(spacing: 12) {
                                RankBadge(rank: store.rank(ex.id), size: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    Text(store.rank(ex.id)?.title ?? "Unranked").font(.caption).foregroundStyle(store.rank(ex.id)?.color ?? Theme.textTertiary)
                                }
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selected ? Theme.accent : Theme.textTertiary)
                            }
                            .card(padding: 12, radius: 16)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(16)
            }
            .background(AppBackground())
            .searchable(text: $query, prompt: "Search exercises")
            .navigationTitle("Showcase \(store.profile.showcase.count)/5")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
        }
    }
}
