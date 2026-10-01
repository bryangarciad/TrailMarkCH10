import SwiftUI
import TrailMarkCH10Core

// Live workout screen. Starts a walk on its own, or shows the one the phone's
// "Start Journey" kicked off — ending it sends the record back to that journey.
struct WorkoutView: View {
    @Environment(WatchModel.self) private var model

    private var workout: WorkoutSessionManager { model.workout }

    var body: some View {
        List {
            if workout.isRunning {
                // Ticks once a second; the manager only publishes on sensor updates.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(elapsedText)
                        .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.yellow)
                }
                .listRowBackground(Color.clear)

                metricRow(value: "\(Int(workout.heartRate))", unit: "bpm", symbol: "heart.fill", tint: .red)
                metricRow(value: "\(Int(workout.activeEnergy))", unit: "kcal", symbol: "flame.fill", tint: .orange)
                metricRow(value: distanceText, unit: "km", symbol: "figure.walk", tint: .green)

                if workout.journeyID != nil {
                    Label("Tracking iPhone journey", systemImage: "iphone")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    workout.end()
                } label: {
                    Label("End", systemImage: "xmark")
                }
            } else {
                Button {
                    workout.start()
                } label: {
                    Label("Start Walk", systemImage: "play.fill")
                }
                .tint(.green)
            }
        }
        .navigationTitle("Workout")
        .task { await workout.requestAuthorization() }
    }

    private func metricRow(value: String, unit: String, symbol: String, tint: Color) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(.system(.title3, design: .rounded, weight: .semibold))
                .contentTransition(.numericText())
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var elapsedText: String {
        let seconds = Int(workout.elapsed)
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }

    private var distanceText: String {
        (workout.distanceMeters / 1000).formatted(.number.precision(.fractionLength(2)))
    }
}

#Preview {
    NavigationStack {
        WorkoutView()
            .environment(WatchModel())
    }
}
