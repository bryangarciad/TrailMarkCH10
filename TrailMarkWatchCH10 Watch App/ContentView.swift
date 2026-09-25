import SwiftUI
import TrailMarkCH10Core

struct ContentView: View {
    @Environment(WatchModel.self) private var model
    
    var body: some View {
        NavigationStack {
            List {
                // Main Screen
                WristHomeView()
                
                // Navigation Menu
                Section {
                    NavigationLink {
                        WristMemoView()
                    } label: {
                        Label("Voice Memo", systemImage: "mic.fill")
                    }
                }
            }
        }
        .navigationTitle("TrailMark WatchOS")
        .task {
            await model.health.requestAuthorization()
            await model.health.refreshTodaysSummary()
        }
    }
}

#Preview {
    ContentView()
}
