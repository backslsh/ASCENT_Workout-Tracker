import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmReset = false
    @State private var message: String?
    @State private var backup: BackupDocument?

    private var bodyweight: Binding<Double> {
        Binding(get: { store.profile.units.display(store.profile.bodyweight) },
                set: { store.profile.bodyweight = max(30, store.profile.units.toKg($0)) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $store.profile.name)
                    Stepper("Age: \(store.profile.age)", value: $store.profile.age, in: 10...100)
                    HStack {
                        Text("Bodyweight")
                        Spacer()
                        NumberField(value: bodyweight)
                            .frame(width: 80, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        Text(store.profile.units.rawValue).foregroundStyle(Theme.textSecondary)
                    }
                    NavigationLink {
                        BodyweightView()
                    } label: {
                        Label("Weight History", systemImage: "chart.xyaxis.line")
                    }
                    Picker("Rank Standards", selection: $store.profile.sex) {
                        Text("Male").tag(StandardSex.male)
                        Text("Female").tag(StandardSex.female)
                    }
                }

                Section("Appearance") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(AccentTheme.allCases) { t in accentSwatch(t) }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                    Toggle("Sound Effects", isOn: $store.profile.sounds)
                        .tint(Theme.accent)
                }

                Section("Training") {
                    Picker("Units", selection: $store.profile.units) {
                        Text("Pounds (lb)").tag(UnitSystem.lb)
                        Text("Kilograms (kg)").tag(UnitSystem.kg)
                    }
                    Picker("Default Rest", selection: $store.profile.defaultRest) {
                        ForEach([30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { s in
                            Text(fmtRest(s)).tag(s)
                        }
                    }
                    Stepper("Weekly Goal: \(store.profile.weeklyGoal)", value: $store.profile.weeklyGoal, in: 1...14)
                    NavigationLink {
                        EquipmentSettingsView()
                    } label: {
                        LabeledContent("My Equipment",
                                       value: store.profile.myEquipment.isEmpty ? "Everything" : "\(store.profile.myEquipment.count) selected")
                    }
                    Toggle("Rest Timer Alerts", isOn: $store.profile.restNotifications)
                        .tint(Theme.accent)
                    Toggle("Lock Screen Live Activity", isOn: $store.profile.liveActivity)
                        .tint(Theme.accent)
                }

                Section {
                    Toggle("Weekly Auto-Backup", isOn: $store.profile.autoBackup)
                        .tint(Theme.accent)
                    LabeledContent("Last Auto-Backup",
                                   value: store.lastAutoBackup.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
                    Button {
                        if store.autoBackupIfNeeded(force: true) {
                            Haptics.success()
                            message = "Backup saved to Files › On My iPhone › Ascend › Backups."
                        } else {
                            message = "Couldn't write the backup file."
                        }
                    } label: {
                        Label("Back Up Now", systemImage: "externaldrive.fill.badge.checkmark")
                    }
                    Button {
                        backup = BackupDocument(data: store.exportData())
                        exporting = true
                    } label: {
                        Label("Export Backup…", systemImage: "square.and.arrow.up")
                    }
                    Button { importing = true } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                        handleImport(result)
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Ascend saves a backup to Files › On My iPhone › Ascend › Backups once a week (the last 6 are kept). Re-signing keeps your data, but deleting the app erases that folder too, so export a copy to iCloud Drive now and then.")
                }

                Section {
                    Button("Reset All Data", role: .destructive) { confirmReset = true }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Exercises", value: "\(store.allExercises.count)")
                    LabeledContent("Account", value: "None — 100% on-device")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .fileExporter(isPresented: $exporting, document: backup, contentType: .json,
                          defaultFilename: "Ascend-Backup-\(Date().formatted(.iso8601.year().month().day()))") { result in
                if case .success = result { message = "Backup exported." }
            }
            .onChange(of: store.profile.restNotifications) { _, on in
                if on { Notifier.request() }
            }
            .onDisappear { store.syncWeightLog() }
            .alert("Reset everything?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { store.resetAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All workouts, routines and ranks will be permanently deleted.")
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            }
        }
    }

    private func accentSwatch(_ t: AccentTheme) -> some View {
        let selected = store.profile.accent == t
        return Button {
            Haptics.select()
            withAnimation(Theme.spring) { store.profile.accent = t }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(LinearGradient(colors: [t.accent, t.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: selected ? 3 : 0))
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                        }
                    }
                    .shadow(color: t.accent.opacity(selected ? 0.6 : 0), radius: 8)
                Text(t.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(selected ? Color.white : Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                try store.importData(data)
                Haptics.success()
                message = "Backup restored."
            } catch {
                Haptics.warning()
                message = "That file isn't a valid Ascend backup."
            }
        case .failure:
            message = "Couldn't open that file."
        }
    }
}

struct EquipmentSettingsView: View {
    @EnvironmentObject var store: AppStore

    private let choices: [Equipment] = [.dumbbell, .kettlebell, .band, .barbell, .machine, .cable, .other]

    var body: some View {
        Form {
            Section {
                ForEach(choices) { e in
                    let owned = store.profile.myEquipment.contains(e)
                    Button {
                        Haptics.select()
                        toggle(e)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: e.symbol)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 28)
                            Text(e.ownedName).foregroundStyle(.white)
                            Spacer()
                            if owned {
                                Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            } header: {
                Text("What do you have?")
            } footer: {
                Text("Bodyweight moves are always included. Leave everything unticked if you train at a full gym.")
            }

            Section {
                Toggle("Filter Exercise Picker", isOn: $store.profile.equipmentFilter)
                    .tint(Theme.accent)
                    .disabled(store.profile.myEquipment.isEmpty)
            } footer: {
                Text("When on, the exercise picker only shows moves you can do with your gear. You can also switch it from the picker's \"My Gear\" chip.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("My Equipment")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ e: Equipment) {
        var p = store.profile
        let wasEmpty = p.myEquipment.isEmpty
        if let i = p.myEquipment.firstIndex(of: e) { p.myEquipment.remove(at: i) } else { p.myEquipment.append(e) }
        if wasEmpty && !p.myEquipment.isEmpty { p.equipmentFilter = true }
        if p.myEquipment.isEmpty { p.equipmentFilter = false }
        store.profile = p
    }
}
