import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: Routine?
    @State private var deleting: Routine?

    private var sortedRoutines: [Routine] {
        store.routines.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return ($0.lastUsed ?? $0.created) > ($1.lastUsed ?? $1.created)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(title: "Workout", subtitle: "\(store.routines.count) routines") {
                        GlassIconButton(symbol: "plus") { editing = Routine(name: "", entries: []) }
                    }

                    quickStartCard

                    NavigationLink { LibraryView() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.accent2)
                                .frame(width: 40, height: 40)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent2.opacity(0.15)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Exercise Library").font(.headline).foregroundStyle(.white)
                                Text("\(store.allExercises.count) exercises · gym & home").font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(Theme.textTertiary)
                        }
                        .card(padding: 14)
                    }
                    .buttonStyle(.pressable)

                    SectionHeader(title: "My Routines", actionTitle: "New") { editing = Routine(name: "", entries: []) }

                    if store.routines.isEmpty {
                        EmptyState(symbol: "list.bullet.rectangle.portrait", title: "No routines yet",
                                   message: "Build a routine once, then start it with a single tap.")
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedRoutines) { r in
                                RoutineRow(routine: r, onEdit: { editing = r }, onDelete: { deleting = r })
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
            .navigationDestination(for: ExerciseRoute.self) { ExerciseDetailView(exerciseID: $0.id) }
            .sheet(item: $editing) { r in
                RoutineEditorView(routine: r).environmentObject(store)
            }
            .alert("Delete routine?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Delete", role: .destructive) {
                    if let d = deleting { withAnimation(Theme.spring) { store.deleteRoutine(d.id) } }
                    deleting = nil
                }
                Button("Cancel", role: .cancel) { deleting = nil }
            } message: {
                Text("\"\(deleting?.name ?? "")\" will be removed. Your workout history is kept.")
            }
        }
    }

    private var quickStartCard: some View {
        Button { store.startEmpty() } label: {
            HStack(spacing: 14) {
                Image(systemName: store.active == nil ? "bolt.fill" : "play.fill")
                    .font(.title2.weight(.bold))
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.white.opacity(0.18)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.active == nil ? "Quick Start" : "Resume Workout").font(.title3.weight(.bold))
                    Text(store.active?.name ?? "Start an empty workout and add as you go")
                        .font(.subheadline)
                        .opacity(0.85)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.headline)
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.accentGradient))
            .shadow(color: Theme.accent.opacity(0.4), radius: 18, y: 8)
        }
        .buttonStyle(.pressable)
    }
}

struct RoutineRow: View {
    @EnvironmentObject var store: AppStore
    let routine: Routine
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var exerciseNames: String {
        routine.entries.compactMap { store.exercise($0.exerciseID)?.name }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if routine.pinned {
                        Image(systemName: "pin.fill").font(.caption).foregroundStyle(Theme.accent)
                    }
                    Text(routine.name).font(.headline).lineLimit(1)
                }
                Text(exerciseNames.isEmpty ? "No exercises" : exerciseNames)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    MuscleStack(groups: store.muscles(of: routine.entries), size: 24)
                    Text("\(routine.entries.reduce(0) { $0 + $1.sets.count }) sets")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Button { store.startWorkout(routine) } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.accentGradient))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.pressable)
            .disabled(routine.entries.isEmpty)
        }
        .card()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { Haptics.tap(); onEdit() }
        .contextMenu {
            Button { store.startWorkout(routine) } label: { Label("Start", systemImage: "play.fill") }
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button { withAnimation(Theme.spring) { store.togglePin(routine.id) } } label: {
                Label(routine.pinned ? "Unpin" : "Pin to Profile", systemImage: routine.pinned ? "pin.slash" : "pin")
            }
            Button { withAnimation(Theme.spring) { store.duplicate(routine) } } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

// MARK: - Routine editor

struct RoutineEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Routine
    @State private var showPicker = false
    private let isNew: Bool

    init(routine: Routine) {
        _draft = State(initialValue: routine)
        isNew = routine.name.isEmpty && routine.entries.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Routine name", text: $draft.name)
                            .font(.title2.weight(.bold))
                            .submitLabel(.done)
                        Toggle(isOn: $draft.pinned) {
                            Label("Pin to Profile", systemImage: "pin.fill").font(.subheadline)
                        }
                        .tint(Theme.accent)
                    }
                    .card()

                    ForEach($draft.entries) { $entry in
                        ExerciseCard(entry: $entry, mode: .plan, bodyweight: store.profile.bodyweight,
                                     onRemove: { remove(entry.id) },
                                     onMoveUp: { move(entry.id, by: -1) },
                                     onMoveDown: { move(entry.id, by: 1) })
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }

                    Button { showPicker = true } label: {
                        Label("Add Exercises", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle(isNew ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var r = draft
                        r.name = r.name.trimmingCharacters(in: .whitespaces)
                        if r.name.isEmpty { r.name = "My Routine" }
                        store.upsert(r)
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(draft.entries.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exs in
                    withAnimation(Theme.spring) { draft.entries += exs.map { store.makeEntry(for: $0) } }
                }
                .environmentObject(store)
            }
        }
    }

    private func remove(_ id: UUID) {
        withAnimation(Theme.spring) { draft.entries.removeAll { $0.id == id } }
    }

    private func move(_ id: UUID, by delta: Int) {
        guard let i = draft.entries.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard j >= 0, j < draft.entries.count else { return }
        withAnimation(Theme.spring) { draft.entries.swapAt(i, j) }
    }
}
