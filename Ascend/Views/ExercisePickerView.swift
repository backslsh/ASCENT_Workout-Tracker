import SwiftUI

struct ExercisePickerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var onAdd: ([Exercise]) -> Void
    @State private var query = ""
    @State private var filter: MuscleGroup? = nil
    @State private var selected: [String] = []
    @State private var showCustom = false

    private var gearFilterOn: Bool { store.profile.equipmentFilter && !store.profile.myEquipment.isEmpty }

    private var filtered: [Exercise] {
        let gear = gearFilterOn
        return store.allExercises
            .filter { ex in
                (filter == nil || ex.muscle == filter)
                    && (query.isEmpty || ex.name.localizedCaseInsensitiveContains(query))
                    && (!gear || store.canDo(ex))
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if !store.profile.myEquipment.isEmpty {
                                Chip(title: "My Gear", color: Theme.accent2, selected: gearFilterOn) {
                                    withAnimation(Theme.snappy) { store.profile.equipmentFilter.toggle() }
                                }
                                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 22)
                            }
                            Chip(title: "All", selected: filter == nil) { withAnimation(Theme.snappy) { filter = nil } }
                            ForEach(MuscleGroup.allCases) { g in
                                Chip(title: g.name, color: g.color, selected: filter == g) {
                                    withAnimation(Theme.snappy) { filter = (filter == g ? nil : g) }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
                    .padding(.bottom, 4)

                    Button { showCustom = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 40, height: 40)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.15)))
                            Text("Create Custom Exercise").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Spacer()
                        }
                        .card(padding: 10, radius: 16)
                    }
                    .buttonStyle(.pressable)

                    ForEach(filtered) { ex in
                        pickerRow(ex)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(AppBackground())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty {
                    PrimaryButton(title: "Add \(selected.count) Exercise\(selected.count == 1 ? "" : "s")", symbol: "plus") {
                        onAdd(selected.compactMap { store.exercise($0) })
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Theme.spring, value: selected.isEmpty)
            .sheet(isPresented: $showCustom) {
                CustomExerciseView { ex in selected.append(ex.id) }
                    .environmentObject(store)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func pickerRow(_ ex: Exercise) -> some View {
        let idx = selected.firstIndex(of: ex.id)
        return Button {
            Haptics.select()
            withAnimation(Theme.snappy) {
                if let idx { selected.remove(at: idx) } else { selected.append(ex.id) }
            }
        } label: {
            HStack(spacing: 12) {
                MuscleIcon(group: ex.muscle, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    Text("\(ex.muscle.name) · \(ex.equipment.name)").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let r = store.rank(ex.id) { RankBadge(rank: r, size: 24) }
                ZStack {
                    Circle()
                        .strokeBorder(idx == nil ? Theme.textTertiary : Color.clear, lineWidth: 1.5)
                        .background(Circle().fill(idx == nil ? Color.clear : Theme.accent))
                    if let idx {
                        Text("\(idx + 1)").font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(idx == nil ? Theme.surface.opacity(0.92) : Theme.accent.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(idx == nil ? Theme.stroke : Theme.accent.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }
}

struct CustomExerciseView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var onCreate: (Exercise) -> Void
    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var kind: ExerciseKind = .weighted
    @State private var equipment: Equipment = .dumbbell

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise name", text: $name)
                }
                Section("Details") {
                    Picker("Muscle Group", selection: $muscle) {
                        ForEach(MuscleGroup.allCases) { g in Text(g.name).tag(g) }
                    }
                    Picker("Tracking", selection: $kind) {
                        ForEach(ExerciseKind.allCases) { k in Text(k.label).tag(k) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { e in Text(e.name).tag(e) }
                    }
                }
                Section {
                    HStack(spacing: 12) {
                        MuscleIcon(group: muscle, size: 40)
                        VStack(alignment: .leading) {
                            Text(name.isEmpty ? "New Exercise" : name).font(.headline)
                            Text("\(muscle.name) · \(kind.label)").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                } footer: {
                    Text("Custom exercises are ranked against a general standard for their equipment type.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let ex = store.addCustom(name: name.trimmingCharacters(in: .whitespaces), muscle: muscle,
                                                 kind: kind, equipment: equipment)
                        Haptics.success()
                        onCreate(ex)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @State private var showCustom = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(MuscleGroup.allCases) { g in
                    let items = store.exercises(in: g)
                        .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                        .sorted { $0.name < $1.name }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                MuscleIcon(group: g, size: 28)
                                Text(g.name).font(.headline)
                                Spacer()
                                RankBadge(rank: store.groupRank(g), size: 22)
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { i, ex in
                                    NavigationLink(value: ExerciseRoute(id: ex.id)) {
                                        libraryRow(ex)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if ex.isCustom {
                                            Button(role: .destructive) { store.deleteCustom(ex.id) } label: {
                                                Label("Delete Custom Exercise", systemImage: "trash")
                                            }
                                        }
                                    }
                                    if i < items.count - 1 { Divider().overlay(Theme.stroke).padding(.leading, 14) }
                                }
                            }
                            .card(padding: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .searchable(text: $query, prompt: "Search exercises")
        .navigationTitle("Exercise Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCustom = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCustom) {
            CustomExerciseView { _ in }.environmentObject(store)
        }
    }

    private func libraryRow(_ ex: Exercise) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ex.name).font(.subheadline.weight(.semibold))
                    if ex.isCustom {
                        Text("CUSTOM").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.15)))
                    }
                }
                Text(store.bests[ex.id] == nil ? ex.equipment.name : "Best: \(store.bestText(ex.id))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            RankBadge(rank: store.rank(ex.id), size: 28)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
