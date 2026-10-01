import Foundation

/// A completed activity, ready to be written to HealthKit as an `HKWorkout`.
public struct WorkoutRecord: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var start: Date
    public var end: Date
    public var activeEnergyKcal: Double
    public var distanceMeters: Double
    /// Average heart rate over the session, if known.
    public var averageHeartRate: Double?
    /// The phone journey this workout was recorded for, when it was started from
    /// "Start Journey". Nil for workouts started on the watch on their own.
    public var journeyID: UUID?

    public init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        activeEnergyKcal: Double = 0,
        distanceMeters: Double = 0,
        averageHeartRate: Double? = nil,
        journeyID: UUID? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.activeEnergyKcal = activeEnergyKcal
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.journeyID = journeyID
    }

    // MARK: - UI Display Helpers

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public var durationText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad // 00:30:00
        return formatter.string(from: duration) ?? "0:00"
    }
}
