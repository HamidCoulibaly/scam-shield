import SwiftUI

@main
struct ScamShieldApp: App {
    @Environment(\.scenePhase) private var phase
    @State private var model = SecurityModel()

    var body: some Scene {
        WindowGroup {
            ContentView().environment(model)
        }
        .backgroundTask(.appRefresh(DailyRefresh.id)) { await DailyRefresh.run() }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .background { DailyRefresh.schedule() }
        }
    }
}
