import Foundation
import Observation
import TrailMarkCH10Core

// Owns the shared TrailMarkCH10Core managers on the wrist. The watch REUSES the same
// managers as the phone, including the same ConnectivityManager.
@MainActor
@Observable
final class WatchModel {
    let health = HealthKitManager()
    let media = MediaStore()
    let motion = MotionManager()
    let connectivity = ConnectivityManager.shared

    init() {
        // Session 3.2 adds `WorkoutSessionManager`. Its finish hook plugs in here:
        //
        //     workout.onFinish = { [weak self] record in
        //         self?.syncFinished(workout: record)
        //     }
        connectivity.activate()
    }

    /// Saves a just-recorded memo locally, then transfers the file to the phone so it
    /// shows up in the iOS journal ("pocket sync").
    func saveAndSync(memoFrom url: URL, duration: TimeInterval) {
        guard let memo = try? media.add(kind: .audio, movingFileFrom: url, duration: duration) else { return }
        connectivity.transfer(memo: memo, fileURL: media.url(for: memo))
    }

    /// Retries a memo whose transfer failed. Same memo ID and file name, so the phone
    /// replaces its copy instead of adding a duplicate.
    func resend(_ memo: MediaMemo) {
        connectivity.transfer(memo: memo, fileURL: media.url(for: memo))
    }

    /// Sends a finished activity to the phone as a queued record, so it arrives even
    /// if the phone is asleep in a pocket.
    func syncFinished(workout record: WorkoutRecord) {
        connectivity.sync(workout: record)
    }
}
