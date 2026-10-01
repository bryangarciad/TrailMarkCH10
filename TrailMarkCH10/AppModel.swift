import Foundation
import Observation
import TrailMarkCH10Core

// Owns the long-lived managers and wires up cross-device sync. Injected into the
// SwiftUI environment so every screen shares one instance of each manager.
@MainActor
@Observable
final class AppModel {
    let health = HealthKitManager()
    let media = MediaStore()
    let location = LocationManager()
    let journeyStore = JourneyStore()
    let connectivity = ConnectivityManager.shared

    init() {
        wireConnectivity()
    }

    /// Files payloads synced over from the watch into the right store, so they show
    /// up in the iOS Journeys / Journal lists.
    private func wireConnectivity() {
        connectivity.onReceiveJourney = { [weak self] journey in
            self?.journeyStore.add(journey)
        }
        connectivity.onReceiveWorkout = { [weak self] workout in
            guard let self else { return }
            // A workout started by "Start Journey" comes back tagged with that journey,
            // so it lands on the journey's details instead of as a separate entry.
            if let journeyID = workout.journeyID,
               var journey = self.journeyStore.journeys.first(where: { $0.id == journeyID }) {
                journey.workout = workout
                self.journeyStore.add(journey) // same ID, so this is an update
                return
            }
            // Wrap a bare workout in a minimal journey so it still surfaces in the list.
            let journey = Journey(
                title: "Watch activity",
                startedAt: workout.start,
                endedAt: workout.end,
                workout: workout
            )
            self.journeyStore.add(journey)
        }
        connectivity.onReceiveMediaFile = { [weak self] tempURL, memo in
            guard let self else { return }
            // Move our copy into the media directory under the memo's own file name,
            // so `media.url(for:)` resolves it exactly like a locally recorded memo.
            let destination = self.media.mediaDirectory.appendingPathComponent(memo.fileName)
            try? FileManager.default.removeItem(at: destination)
            guard (try? FileManager.default.moveItem(at: tempURL, to: destination)) != nil else { return }
            self.media.register(memo)
        }
        connectivity.activate()
    }

    // MARK: - Journey workouts

    /// Starts the watch workout that tracks a journey: launches the watch app into a
    /// workout session, and tells it which journey the session belongs to.
    func startWorkout(for journeyID: UUID) {
        health.startWatchWorkout()
        connectivity.send(workoutControl: WorkoutControl(.start, journeyID: journeyID))
    }

    /// Ends the journey's watch workout. The watch saves it to Health and sends the
    /// finished record back, which `onReceiveWorkout` attaches to the journey.
    func endWorkout(for journeyID: UUID) {
        connectivity.send(workoutControl: WorkoutControl(.end, journeyID: journeyID))
    }

    /// Pushes today's summary to the watch as glanceable mirrored state.
    func mirrorTodayToWatch() {
        connectivity.sync(summary: health.todaysSummary)
    }
}
