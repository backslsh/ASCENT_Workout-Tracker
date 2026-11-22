import SwiftUI
import Charts

struct WeekPoint: Identifiable {
    let id: Date
    let count: Int
    let volume: Double
}

struct MonthGroup: Identifiable {
    let id: Date
    let sessions: [WorkoutSession]
}

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var metric = 0

    private var weeks: [WeekPoint] {
        let cal = Calendar.current
        guard let current = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return (0..<8).reversed().compactMap { i -> WeekPoint? in
            guard let start = cal.date(byAdding: .weekOfYear, value: -i, to: current),
                  let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let s = store.sessions.filter { $0.start >= start && $0.start < end }
            return WeekPoint(id: start, count: s.count, volume: s.reduce(0) { $0 + $1.volume })
        }
    }

    private var months: [MonthGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: store.sessions) { cal.dateInterval(of: .month, for: $0.start)?.start ?? $0.start }
        return grouped.keys.sorted(by: >).map { MonthGroup(id: $0, sessions: (grouped[$0] ?? []).sorted { $0.start > $1.start }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "History", subtitle: "\(store.sessions.count) workouts logged")
                    chartCard
                    HStack(spacing: 10) {
                        StatTile(value: compactWeight(store.totalVolume), label: "Total volume", symbol: "scalemass.fill", color: Theme.accent2)
                        StatTile(value: fmtShortDuration(store.sessions.reduce(0) { $0 + $1.duration }), label: "Time trained", symbol: "clock.fill", color: Theme.accent)
                    }
                    if store.sessions.isEmpty {
                        EmptyState(symbol: "calendar.badge.clock", title: "No workouts yet",
                                   message: "Finished workouts land here with every set you logged.")
                    } else {
                        ForEach(months) { m in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(m.id.formatted(.dateTime.month(.wide).year()))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.textSecondary)
                                ForEach(m.sessions) { s in
                                    NavigationLink(value: s.id) { SessionCard(session: s) }
                                        .buttonStyle(.pressable)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { SessionDetailView(sessionID: $0) }
        }
    }

    private func compactWeight(_ kg: Double) -> String {
        let v = store.profile.units.display(kg)
        return "\(v.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))) \(store.profile.units.rawValue)"
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 8 weeks").font(.headline)
                Spacer()
                Picker("Metric", selection: $metric) {
                    Text("Workouts").tag(0)
                    Text("Volume").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            Chart(weeks) { w in
                BarMark(x: .value("Week", w.id, unit: .weekOfYear),
                        y: .value("Value", metric == 0 ? Double(w.count) : store.profile.units.display(w.volume)))
                    .foregroundStyle(Theme.accentGradient)
                    .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 150)
            .animation(Theme.spring, value: metric)
        }
        .card()
    }
}

struct SessionCard: View {
    @EnvironmentObject var store: AppStore
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text(session.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                MuscleStack(groups: store.muscles(of: session.entries), size: 26)
            }
            HStack(spacing: 14) {
                InfoPill(symbol: "clock", text: fmtShortDuration(session.duration))
                InfoPill(symbol: "scalemass", text: store.weightText(session.volume))
                InfoPill(symbol: "checkmark.circle", text: "\(session.completedSets) sets")
            }
            Text(session.entries.compactMap { store.exercise($0.exerciseID)?.name }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

struct SessionDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID
    @State private var confirmDelete = false
    @State private var saved = false

    var body: some View {
        if let s = store.sessions.first(where: { $0.id == sessionID }) {
            content(s)
        } else {
            AppBackground()
        }
    }

    private func content(_ s: WorkoutSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.name).font(.system(.title, design: .rounded).weight(.bold))
                    Text(s.start.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 10) {
                    StatTile(value: fmtShortDuration(s.duration), label: "Duration", symbol: "clock.fill", color: Theme.accent)
                    StatTile(value: store.weightText(s.volume), label: "Volume", symbol: "scalemass.fill", color: Theme.accent2)
                    StatTile(value: "\(s.completedSets)", label: "Sets", symbol: "checkmark.circle.fill", color: Theme.success)
                }
                ForEach(s.entries) { e in
                    let ex = store.exercise(e.exerciseID) ?? .unknown
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            MuscleIcon(group: ex.muscle, size: 34)
                            Text(ex.name).font(.headline)
                            Spacer()
                            RankBadge(rank: store.rank(ex.id), size: 26)
                        }
                        ForEach(Array(e.sets.enumerated()), id: \.element.id) { i, set in
                            HStack {
                                Text(set.isWarmup ? "W" : "\(i + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(set.isWarmup ? Theme.warning : Theme.textSecondary)
                                    .frame(width: 24)
                                Text(store.setText(set, ex)).font(.subheadline.monospacedDigit())
                                Spacer()
                                if ex.kind == .weighted {
                                    Text("1RM \(store.weightText(RankEngine.e1RM(weight: set.weight, reps: set.reps)))")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                    }
                    .card(padding: 14)
                }
                PrimaryButton(title: "Repeat Workout", symbol: "arrow.clockwise") { store.repeatSession(s) }
                    .padding(.top, 4)
                SecondaryButton(title: saved ? "Saved to Routines" : "Save as Routine",
                                symbol: saved ? "checkmark" : "square.and.arrow.down",
                                tint: saved ? Theme.success : .white) {
                    guard !saved else { return }
                    store.saveAsRoutine(s)
                    withAnimation(Theme.snappy) { saved = true }
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Text("Delete Workout").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this workout? This can't be undone.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let id = s.id
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { store.deleteSession(id) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
