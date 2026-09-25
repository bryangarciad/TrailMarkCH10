import SwiftUI
import TrailMarkCH10Core

struct ContentView: View {
    @Environment(AppModel.self) private var model
    
    var body: some View {
        TabView {
            TodayDashboardView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            JourneyListView()
                .tabItem { Label("Journeys", systemImage: "map.fill") }
            FieldJournalView()
                .tabItem { Label("Journal", systemImage: "waveform") }
            RecoveryView()
                .tabItem { Label("Recovery", systemImage: "bed.double.fill") }
        }
        .task {
            await model.health.requestAuthorization()
            await model.health.refreshTodaysSummary()
            model.mirrorTodayToWatch()
        }
    }
}

#Preview {
    ContentView()
}
