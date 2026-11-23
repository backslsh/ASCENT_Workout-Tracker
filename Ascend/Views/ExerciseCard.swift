import SwiftUI

private let restOptions = [0, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

struct ExerciseCard: View {
    @EnvironmentObject var store: AppStore
    @Binding var entry: ExerciseEntry
    let mode: CardMode
    var bodyweight: Double
    var superset: SupersetInfo? = nil
    var onRemove: () -> Void
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var onLinkNext: (() -> Void)? = nil
    var onUnlink: (() -> Void)? = nil

    @State private var editingNote = false
    @State private var noteDraft = ""
    @State private var showPlates = false
    @State private var hintDismissed = false

    private var exercise: Exercise { store.exercise(entry.exerciseID) ?? .unknown }
    private var previous: [SetEntry] {
        mode == .live ? (store.lastSets(for: entry.exerciseID) ?? []).filter { !$0.isWarmup } : []
    }

    var body: some View {
        let ex = exercise
        let prev = previous
        let best = store.bests[ex.id]?.perf ?? 0
        let note = store.note(for: ex.id)
        VStack(alignment: .leading, spacing: 10) {
            header(ex)
            if !note.isEmpty { noteRow(note) }
            if let hint = activeHint { hintRow(hint) }
            columnHeader(ex)
            VStack(spacing: 6) {
                ForEach($entry.sets) { $set in
                    let n = workingNumber(set.id)
                    SetRow(set: $set,
                           number: n,
                           exercise: ex,
                           mode: mode,
                           previous: (n > 0 && n <= prev.count && !set.isWarmup) ? prev[n - 1] : nil,
                           isPR: isPR(set, ex, best),
                           onToggle: { toggle(set.id) },
                           onDelete: { deleteSet(set.id) })
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                }
            }
            Button(action: addSet) {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.12)))
            }
            .buttonStyle(.pressable)
        }
        .card(padding: 14)
        .overlay(alignment: .leading) {
            if let superset {
                Capsule().fill(superset.color).frame(width: 4).padding(.vertical, 22).offset(x: 1)
            }
        }
        .alert("Exercise Note", isPresented: $editingNote) {
            TextField("e.g. Seat on notch 4", text: $noteDraft)
            Button("Save") { store.setNote(noteDraft, for: ex.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shown every time you do \(ex.name).")
        }
        .sheet(isPresented: $showPlates) {
            PlateCalculatorView(initialKg: plateTarget, onApply: { kg in applyWeight(kg) })
                .environmentObject(store)
        }
    }

    // MARK: Header

    @ViewBuilder
    private func header(_ ex: Exercise) -> some View {
        HStack(spacing: 12) {
            MuscleIcon(group: ex.muscle, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name).font(.headline).lineLimit(1)
                if let superset {
                    Label(superset.label.uppercased(), systemImage: "link")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(superset.color)
                }
                HStack(spacing: 6) {
                    Text(ex.muscle.name)
                    Text("·")
                    Image(systemName: "timer")
                    Text(superset != nil && superset?.isLast == false ? "No rest" : fmtRest(entry.restSeconds))
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            if isBarbell {
                Button {
                    Haptics.tap()
                    showPlates = true
                } label: {
                    Image(systemName: "circle.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accent2)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.accent2.opacity(0.12)))
                }
                .buttonStyle(.pressable)
            }
            if mode == .live {
                RankBadge(rank: store.rank(ex.id), size: 28)
            }
            Menu {
                Menu {
                    ForEach(restOptions, id: \.self) { s in
                        Button { entry.restSeconds = s } label: {
                            if entry.restSeconds == s {
                                Label(fmtRest(s), systemImage: "checkmark")
                            } else {
                                Text(fmtRest(s))
                            }
                        }
                    }
                } label: {
                    Label("Rest Timer (\(fmtRest(entry.restSeconds)))", systemImage: "timer")
                }
                Button {
                    noteDraft = store.note(for: ex.id)
                    editingNote = true
                } label: {
                    Label(store.note(for: ex.id).isEmpty ? "Add Note" : "Edit Note", systemImage: "note.text")
                }
                if isBarbell {
                    Button { showPlates = true } label: { Label("Plate Calculator", systemImage: "circle.circle") }
                }
                if let onLinkNext {
                    Button(action: onLinkNext) { Label("Superset with Next", systemImage: "link") }
                }
                if let onUnlink {
                    Button(action: onUnlink) { Label("Remove from Superset", systemImage: "minus.circle") }
                }
                if let onMoveUp {
                    Button(action: onMoveUp) { Label("Move Up", systemImage: "arrow.up") }
                }
                if let onMoveDown {
                    Button(action: onMoveDown) { Label("Move Down", systemImage: "arrow.down") }
                }
                Divider()
                Button(role: .destructive, action: onRemove) { Label("Remove Exercise", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
    }

    private func columnHeader(_ ex: Exercise) -> some View {
        let unit = store.profile.units.rawValue.uppercased()
        return HStack(spacing: 8) {
            Text("SET").frame(width: 30)
            if mode == .live { Text("PREVIOUS").frame(maxWidth: .infinity) }
            Text(ex.kind == .weighted ? unit : "+\(unit)").column(mode, width: 68)
            Text(ex.kind == .timed ? "SEC" : "REPS").column(mode, width: 58)
            Color.clear.frame(width: 36, height: 1)
        }
        .font(.caption2.weight(.bold))
        .tracking(0.6)
        .foregroundStyle(Theme.textTertiary)
        .padding(.horizontal, 4)
    }

    // MARK: Note & progression hint

    private func noteRow(_ note: String) -> some View {
        Button {
            noteDraft = note
            editingNote = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text").font(.caption.weight(.bold)).foregroundStyle(Theme.warning)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.warning.opacity(0.10)))
        }
        .buttonStyle(.pressable)
    }

    private var activeHint: ProgressionHint? {
        guard mode == .live, !hintDismissed, !entry.sets.contains(where: { $0.done && !$0.isWarmup }) else { return nil }
        return store.progressionHint(for: entry)
    }

    private func hintRow(_ h: ProgressionHint) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.success)
            VStack(alignment: .leading, spacing: 1) {
                Text(h.title).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(h.detail).font(.caption2).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.success()
                var e = entry
                store.apply(h, to: &e)
                withAnimation(Theme.snappy) {
                    entry = e
                    hintDismissed = true
                }
            } label: {
                Text("Apply")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(Theme.success))
            }
            .buttonStyle(.pressable)
            Button {
                Haptics.tap()
                withAnimation(Theme.snappy) { hintDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 24, height: 30)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.success.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.success.opacity(0.25), lineWidth: 1))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: Plates

    private var isBarbell: Bool { exercise.equipment == .barbell && exercise.kind == .weighted }

    private var plateTarget: Double {
        let working = entry.sets.filter { !$0.isWarmup }
        if let s = working.first(where: { !$0.done && $0.weight > 0 }) { return s.weight }
        return working.last?.weight ?? entry.sets.last?.weight ?? 0
    }

    private func applyWeight(_ kg: Double) {
        withAnimation(Theme.snappy) {
            for i in entry.sets.indices where !entry.sets[i].done && !entry.sets[i].isWarmup {
                entry.sets[i].weight = kg
            }
        }
    }

    // MARK: Sets

    private func workingNumber(_ id: UUID) -> Int {
        var n = 0
        for s in entry.sets {
            if !s.isWarmup { n += 1 }
            if s.id == id { return s.isWarmup ? 0 : n }
        }
        return n
    }

    private func isPR(_ set: SetEntry, _ ex: Exercise, _ best: Double) -> Bool {
        guard mode == .live, set.done, !set.isWarmup, best > 0 else { return false }
        return RankEngine.performance(of: set, exercise: ex, bodyweight: bodyweight) > best + 1e-9
    }

    private func toggle(_ id: UUID) {
        guard let i = entry.sets.firstIndex(where: { $0.id == id }) else { return }
        hideKeyboard()
        if !entry.sets[i].done, entry.sets[i].reps == 0, entry.sets[i].seconds == 0 {
            let n = workingNumber(id)
            let prev = previous
            if n > 0, n <= prev.count {
                entry.sets[i].reps = prev[n - 1].reps
                entry.sets[i].seconds = prev[n - 1].seconds
                if entry.sets[i].weight == 0 { entry.sets[i].weight = prev[n - 1].weight }
            }
        }
        withAnimation(Theme.snappy) { entry.sets[i].done.toggle() }
        if entry.sets[i].done {
            Haptics.medium()
            let ex = exercise
            if isPR(entry.sets[i], ex, store.bests[ex.id]?.perf ?? 0) { Sounds.pr() } else { Sounds.setDone() }
            // In a superset, rest only after the last exercise of the group.
            if superset == nil || superset?.isLast == true {
                store.startRest(entry.restSeconds)
            }
        } else {
            Haptics.tap()
        }
    }

    private func addSet() {
        Haptics.tap()
        let last = entry.sets.last
        let timed = exercise.kind == .timed
        let new = SetEntry(weight: last?.weight ?? 0,
                           reps: last?.reps ?? (timed ? 0 : 10),
                           seconds: last?.seconds ?? (timed ? 30 : 0))
        withAnimation(Theme.snappy) { entry.sets.append(new) }
    }

    private func deleteSet(_ id: UUID) {
        Haptics.tap()
        withAnimation(Theme.snappy) { entry.sets.removeAll { $0.id == id } }
    }
}

struct SetRow: View {
    @EnvironmentObject var store: AppStore
    @Binding var set: SetEntry
    let number: Int
    let exercise: Exercise
    let mode: CardMode
    let previous: SetEntry?
    let isPR: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var units: UnitSystem { store.profile.units }

    private var weightBinding: Binding<Double> {
        Binding(get: { units.display(set.weight) },
                set: { set.weight = max(0, units.toKg($0)) })
    }

    private var countBinding: Binding<Double> {
        let timed = exercise.kind == .timed
        return Binding(get: { Double(timed ? set.seconds : set.reps) },
                       set: { v in
                           let i = max(0, Int(v))
                           if timed { set.seconds = i } else { set.reps = i }
                       })
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    Haptics.select()
                    set.isWarmup.toggle()
                } label: {
                    Label(set.isWarmup ? "Mark as Working Set" : "Mark as Warm-up", systemImage: "flame")
                }
                Button(role: .destructive, action: onDelete) { Label("Delete Set", systemImage: "trash") }
            } label: {
                Text(set.isWarmup ? "W" : "\(number)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(set.isWarmup ? Theme.warning : Color.white.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .frame(width: 30)

            if mode == .live {
                previousLabel.frame(maxWidth: .infinity)
            }

            NumberField(value: weightBinding, placeholder: "0")
                .fieldStyle(done: set.done)
                .column(mode, width: 68)

            NumberField(value: countBinding, placeholder: "0", decimals: false)
                .fieldStyle(done: set.done)
                .column(mode, width: 58)

            if mode == .live {
                Button(action: onToggle) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(set.done ? Color.black : Color.white.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(set.done ? Theme.success : Color.white.opacity(0.08)))
                        .symbolEffect(.bounce, value: set.done)
                }
                .buttonStyle(.pressable)
            } else {
                Button(action: onDelete) {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.danger.opacity(0.12)))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(set.done ? Theme.success.opacity(0.10) : Color.clear))
    }

    @ViewBuilder
    private var previousLabel: some View {
        if isPR {
            Label("PR", systemImage: "trophy.fill")
                .font(.caption.weight(.heavy))
                .foregroundStyle(RankTier.gold.colors[0])
                .transition(.scale.combined(with: .opacity))
        } else if let p = previous {
            Text(store.setText(p, exercise))
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text("—").font(.caption).foregroundStyle(Theme.textTertiary)
        }
    }
}
