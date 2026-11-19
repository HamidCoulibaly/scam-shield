import SwiftUI

struct ContentView: View {
    @Environment(SecurityModel.self) private var model
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Overview", systemImage: "shield.lefthalf.filled") }
            CallsView()
                .tabItem { Label("Calls", systemImage: "phone.fill") }
            SetupView()
                .tabItem { Label("Setup", systemImage: "checklist") }
        }
        .tint(.shieldAccent)
        .task { await model.refresh() }
        .onChange(of: phase) { _, newPhase in
            // Back from Settings or another app: re-run the live checks.
            if newPhase == .active { Task { await model.refresh() } }
        }
    }
}
