import SwiftUI

@main
struct AscendApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.saveNow() }
        }
    }
}
