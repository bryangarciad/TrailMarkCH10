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
            // Wrap a bare workout in a minimal journey so it still surfaces in the list.
            let journey = Journey(
                title: "Watch activity",
                startedAt: workout.start,
                endedAt: workout.end,
                workout: workout
            )
            self?.journeyStore.add(journey)
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

    /// Pushes today's summary to the watch as glanceable mirrored state.
    func mirrorTodayToWatch() {
        connectivity.sync(summary: health.todaysSummary)
    }
}
