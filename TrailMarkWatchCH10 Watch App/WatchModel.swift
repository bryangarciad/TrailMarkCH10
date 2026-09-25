import Foundation
import Observation
import TrailMarkCH10Core

@MainActor
@Observable
final class WatchModel {
    let health = HealthKitManager()
    let media = MediaStore()
    let motion = MotionManager()
}
