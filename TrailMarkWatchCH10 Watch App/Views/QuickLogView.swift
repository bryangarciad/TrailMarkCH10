import SwiftUI
import TrailMarkCH10Core

// Logs a finished activity by hand and queues it for the phone. A stand-in until
// Session 3.2 records real workout sessions.
struct QuickLogView: View {
    @Environment(WatchModel.self) private var model

    @State private var minutes = 30
    @State private var loggedCount = 0

    /// Rough walking pace used to estimate distance.
    private static let metersPerMinute = 80.0

    var body: some View {
        List {
            Section {
                Stepper(value: $minutes, in: 5...60, step: 5) {
                    Text("\(minutes) min")
                        .font(.title3.monospacedDigit())
                }
            } footer: {
                Text("≈ \(Int(Double(minutes) * Self.metersPerMinute)) m walk")
            }

            Section {
                Button {
                    log()
                } label: {
                    Label("Log", systemImage: "square.and.arrow.up")
                }

                if loggedCount > 0 {
                    Label(
                        model.connectivity.pendingRecordCount > 0 ? "Queued for iPhone" : "Sent to iPhone",
                        systemImage: model.connectivity.pendingRecordCount > 0
                            ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(model.connectivity.pendingRecordCount > 0 ? Color.secondary : Color.green)
                }
            }
        }
        .navigationTitle("Quick Log")
    }

    private func log() {
        let end = Date()
        let record = WorkoutRecord(
            start: end.addingTimeInterval(-Double(minutes) * 60),
            end: end,
            distanceMeters: Double(minutes) * Self.metersPerMinute
        )
        model.syncFinished(workout: record)
        loggedCount += 1
    }
}

#Preview {
    NavigationStack {
        QuickLogView()
            .environment(WatchModel())
    }
}
