#if os(watchOS)
import Foundation
import HealthKit
import Observation

@MainActor
@Observable
public final class WorkoutSessionManager: NSObject {

    // This flag is to communicate the UI that there is a workout in progress
    public private(set) var isRunning: Bool = false

    public private(set) var heartRate: Double = 0.0
    public private(set) var activeEnergy: Double = 0.0
    public private(set) var distanceMeters: Double = 0.0
    public private(set) var startDate: Date?

    /// The phone journey this workout belongs to, when it was started by "Start Journey".
    public private(set) var journeyID: UUID?

    // Callback function that will be executed once the workout is completed by the user
    public var onFinish: ((WorkoutRecord) -> Void)?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    public override init() { super.init() }

    public var elapsed: TimeInterval {
        guard let startDate else { return 0 }
        return Date().timeIntervalSince(startDate) // return number of seconds betwen startDate and Current Date
    }

    // MARK: - Authorization

    /// Workouts need their own types on top of HealthKitManager's: heart rate to read
    /// live, and the workout itself to save.
    public func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let energy = HKQuantityType(.activeEnergyBurned)
        let distance = HKQuantityType(.distanceWalkingRunning)
        try? await store.requestAuthorization(
            toShare: [HKObjectType.workoutType(), energy, distance],
            read: [HKQuantityType(.heartRate), energy, distance]
        )
    }

    // MARK: - LifeCycle Control Functions

    /// Starts a walking workout. Safe to call twice: the phone's "Start Journey" both
    /// launches the app with a workout configuration AND sends a start command, and
    /// whichever arrives second just attaches the journey ID.
    public func start(journeyID: UUID? = nil) {
        if let journeyID, self.journeyID == nil { self.journeyID = journeyID }
        guard session == nil else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration) // Getting data straigh from sensors

            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder

            let now = Date()
            startDate = now
            heartRate = 0
            activeEnergy = 0
            distanceMeters = 0

            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { [weak self] success, _ in
                Task { @MainActor in
                    if success {
                        self?.isRunning = true
                    } else {
                        self?.reset()
                    }
                }
            }
        }
        catch {
            reset()
        }
    }

    public func end() {
        guard let session, let builder else { return }
        let endDate = Date()
        session.end()
        builder.endCollection(withEnd: endDate) { [weak self] _, _ in
            Task { @MainActor in self?.finishWorkout(end: endDate) }
        }
    }

    /// Saves the HKWorkout to Health. Hopping back to the MainActor first keeps the
    /// (non-Sendable) builder from being captured by HealthKit's background callback.
    private func finishWorkout(end: Date) {
        builder?.finishWorkout { [weak self] _, _ in
            Task { @MainActor in self?.finalize(end: end) }
        }
    }

    private func finalize(end: Date) {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let averageBPM = builder?.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?.doubleValue(for: bpmUnit)

        let record = WorkoutRecord(
            start: startDate ?? end,
            end: end,
            activeEnergyKcal: activeEnergy,
            distanceMeters: distanceMeters,
            averageHeartRate: averageBPM ?? (heartRate > 0 ? heartRate : nil),
            journeyID: journeyID
        )
        reset()
        onFinish?(record)
    }

    private func reset() {
        isRunning = false
        journeyID = nil
        session = nil
        builder = nil
    }
}

// MARK: - Session Delegator (listen for all session events)
extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated public func workoutSession(
        _ session: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in self.reset() }
    }

    nonisolated public func workoutSession(
        _ session: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            self.isRunning = toState == .running
        }
    }
}

// MARK: - Builder Delegator (lister for all builder envents)
extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }

    nonisolated public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            // This guard acts as a filter so we just collect quantityTypes that also have statistics on them
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

            switch quantityType {
            case HKQuantityType(.heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0.0
                Task { @MainActor in self.heartRate = bpm }

            case HKQuantityType(.activeEnergyBurned):
                let kcal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0
                Task { @MainActor in self.activeEnergy = kcal }

            case HKQuantityType(.distanceWalkingRunning):
                let distance = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0.0
                Task { @MainActor in self.distanceMeters = distance }

            default:
                break
            }
        }
    }
}

#endif
