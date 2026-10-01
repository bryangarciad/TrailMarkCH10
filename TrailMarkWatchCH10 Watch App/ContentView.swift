import SwiftUI
import TrailMarkCH10Core

struct ContentView: View {
    @Environment(WatchModel.self) private var model

    @State private var showingWorkout = false
    
    var body: some View {
        NavigationStack {
            List {
                // Main Screen
                WristHomeView()
                
                // Navigation Menu
                Section {
                    NavigationLink {
                        WorkoutView()
                    } label: {
                        Label(model.workout.isRunning ? "Workout · Live" : "Workout", systemImage: "figure.walk.motion")
                    }
                    NavigationLink {
                        WristMemoView()
                    } label: {
                        Label("Voice Memo", systemImage: "mic.fill")
                    }
                    NavigationLink {
                        QuickLogView()
                    } label: {
                        Label("Quick Log", systemImage: "figure.walk")
                    }
                }
            }
            // A workout started from the phone's "Start Journey" jumps straight to it.
            .navigationDestination(isPresented: $showingWorkout) { WorkoutView() }
        }
        .navigationTitle("TrailMark WatchOS")
        .onChange(of: model.workout.isRunning) { _, isRunning in
            if isRunning { showingWorkout = true }
        }
        .task {
            await model.health.requestAuthorization()
            await model.health.refreshTodaysSummary()
            await model.workout.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
}
