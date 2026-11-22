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
                    Picker("Rank Standards", selection: $store.profile.sex) {
                        Text("Male").tag(StandardSex.male)
                        Text("Female").tag(StandardSex.female)
                    }
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
                    Toggle("Rest Timer Alerts", isOn: $store.profile.restNotifications)
                        .tint(Theme.accent)
                }

                Section {
                    Button {
                        backup = BackupDocument(data: store.exportData())
                        exporting = true
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
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
                    Text("Free sideloading needs a re-sign every 7 days. Re-signing keeps your data, but deleting the app erases it — export a backup now and then. Your data file is also visible in the Files app under On My iPhone › Ascend.")
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
