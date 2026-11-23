import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: AppStore
    @State private var showPicker = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var renaming = false

    private var session: Binding<WorkoutSession> {
        Binding(get: { store.active ?? .empty },
                set: { if store.active != nil { store.active = $0 } })
    }

    private var pendingSets: Int {
        session.wrappedValue.entries.reduce(0) { $0 + $1.sets.filter { !$0.done }.count }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 14) {
                        LiveStatsRow(session: session.wrappedValue)

                        if session.wrappedValue.entries.isEmpty {
                            EmptyState(symbol: "dumbbell.fill", title: "Empty workout",
                                       message: "Add exercises to start logging sets.")
                        }

                        ForEach(session.entries) { $entry in
                            let all = session.wrappedValue.entries
                            let info = all.supersetInfo(for: entry.id)
                            ExerciseCard(entry: $entry, mode: .live,
                                         bodyweight: session.wrappedValue.bodyweight ?? store.profile.bodyweight,
                                         superset: info,
                                         onRemove: { remove(entry.id) },
                                         onMoveUp: { move(entry.id, by: -1) },
                                         onMoveDown: { move(entry.id, by: 1) },
                                         onLinkNext: all.canLinkWithNext(entry.id) ? { link(entry.id) } : nil,
                                         onUnlink: info != nil ? { unlink(entry.id) } : nil)
                                .padding(.top, info != nil && info?.isFirst == false ? -8 : 0)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }

                        Button { showPicker = true } label: {
                            Label("Add Exercise", systemImage: "plus")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                        }
                        .buttonStyle(.pressable)

                        PrimaryButton(title: "Finish Workout", symbol: "flag.checkered") { confirmFinish = true }
                            .padding(.top, 6)

                        Button(role: .destructive) { confirmDiscard = true } label: {
                            Text("Discard Workout").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.danger)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)

                RestTimerBar()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .animation(Theme.spring, value: store.restEnd != nil)
            .background(AppBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        store.showActive = false
                    } label: {
                        Image(systemName: "chevron.down").fontWeight(.bold)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button { renaming = true } label: {
                        HStack(spacing: 4) {
                            Text(session.wrappedValue.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                            Image(systemName: "pencil").font(.caption2).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { confirmFinish = true }
                        .fontWeight(.bold)
                        .tint(Theme.success)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }.fontWeight(.semibold)
                }
            }
            .alert("Rename Workout", isPresented: $renaming) {
                TextField("Name", text: session.name)
                Button("OK") {}
            }
            .confirmationDialog(finishTitle, isPresented: $confirmFinish, titleVisibility: .visible) {
                Button(session.wrappedValue.completedSets == 0 ? "End & Discard" : "Finish Workout") {
                    Haptics.success()
                    store.finishWorkout()
                }
                Button("Keep Going", role: .cancel) {}
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    Haptics.warning()
                    store.discardWorkout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exs in
                    withAnimation(Theme.spring) {
                        store.active?.entries += exs.map { store.makeEntry(for: $0) }
                    }
                }
                .environmentObject(store)
            }
        }
    }

    private var finishTitle: String {
        if session.wrappedValue.completedSets == 0 { return "No sets completed yet — nothing will be saved." }
        if pendingSets > 0 { return "\(pendingSets) unchecked set\(pendingSets == 1 ? "" : "s") won't be saved." }
        return "Great work! Ready to finish?"
    }

    private func remove(_ id: UUID) {
        guard var s = store.active else { return }
        s.entries.removeAll { $0.id == id }
        s.entries.normalizeSupersets()
        withAnimation(Theme.spring) { store.active = s }
    }

    private func move(_ id: UUID, by delta: Int) {
        guard var s = store.active, let i = s.entries.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard j >= 0, j < s.entries.count else { return }
        s.entries.swapAt(i, j)
        s.entries.normalizeSupersets()
        withAnimation(Theme.spring) { store.active = s }
    }

    private func link(_ id: UUID) {
        guard var s = store.active else { return }
        Haptics.select()
        s.entries.linkWithNext(id)
        withAnimation(Theme.spring) { store.active = s }
    }

    private func unlink(_ id: UUID) {
        guard var s = store.active else { return }
        Haptics.tap()
        s.entries.unlinkSuperset(id)
        withAnimation(Theme.spring) { store.active = s }
    }
}

struct LiveStatsRow: View {
    @EnvironmentObject var store: AppStore
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                stat(fmtDuration(ctx.date.timeIntervalSince(session.start)), "Duration")
            }
            divider
            stat(store.weightText(session.volume), "Volume")
            divider
            stat("\(session.completedSets)", "Sets")
        }
        .padding(.vertical, 14)
        .liquidGlass(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 30)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RestTimerBar: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        if let end = store.restEnd {
            TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                let remaining = max(0, end.timeIntervalSince(ctx.date))
                let total = Double(max(store.restTotal, 1))
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: min(1, remaining / total))
                            .stroke(Theme.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "timer").font(.system(size: 13, weight: .bold))
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("REST").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(Theme.textSecondary)
                        Text(fmtDuration(remaining.rounded(.up)))
                            .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                    }
                    Spacer(minLength: 0)
                    pill("-15") { store.adjustRest(-15) }
                    pill("+15") { store.adjustRest(15) }
                    Button {
                        Haptics.tap()
                        store.cancelRest()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Theme.accentGradient))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, 12)
                .frame(height: 64)
                .liquidGlass(Capsule(), interactive: true, tint: Theme.accent.opacity(0.18))
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func pill(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 34)
                .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.pressable)
    }
}
