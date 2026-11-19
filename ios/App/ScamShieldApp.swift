import SwiftUI

@main
struct ScamShieldApp: App {
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup { ContentView() }
            .backgroundTask(.appRefresh(DailyRefresh.id)) { await DailyRefresh.run() }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .background { DailyRefresh.schedule() }
            }
    }
}
