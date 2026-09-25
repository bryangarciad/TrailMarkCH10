import Foundation
import HealthKit
import Observation

@MainActor
@Observable
public final class HealthKitManager {

    public enum AuthorizationState: Equatable {
        case unknown
        case unavailable
        case requesting
        case authorized
        case denied
    }
    
    public private(set) var currentAuthStatus: AuthorizationState = .unknown

    public private(set) var todaysSummary: ActivitySummary = .empty

    public private(set) var sleep: SleepSummary = .empty

    public private(set) var energyTrend: [EnergyTrendPoint] = []
    
    public private(set) var liveVitals: LiveVitals = .empty

    private let store = HKHealthStore()
    private var openLiveQueries: [HKQuery] = []
    
    public init() {
        if !HKHealthStore.isHealthDataAvailable() {
            currentAuthStatus = .unavailable
        }
    }
    
    // MARK: - Authorization Framework
    
    private var stepsType: HKQuantityType { HKQuantityType(.stepCount) }
    private var distanceType: HKQuantityType { HKQuantityType(.distanceWalkingRunning) }
    private var energyType: HKQuantityType { HKQuantityType(.activeEnergyBurned) }
    private var sleepType: HKCategoryType { HKCategoryType(.sleepAnalysis) } // Awake, REM, Core, Deep
    private var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }
    
    private var readTypes: Set<HKObjectType> {
        [stepsType, distanceType, energyType, sleepType]
    }

    private var shareTypes: Set<HKSampleType> {
        [energyType, distanceType, HKObjectType.workoutType()]
    }
    
    public func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            currentAuthStatus = .unavailable
            return
        }
        currentAuthStatus = .requesting
        do {
            try await store.requestAuthorization(toShare:  shareTypes, read: readTypes)
            currentAuthStatus = .authorized
        } catch {
            currentAuthStatus = .denied
        }
    }
    
    public func refreshTodaysSummary() async {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        async let steps = sumQuantity(stepsType, unit: .count(), since: startOfDay)
        async let distance = sumQuantity(distanceType, unit: .meter(), since: startOfDay)
        async let energy = sumQuantity(energyType, unit: .kilocalorie(), since: startOfDay)
        
        todaysSummary = ActivitySummary(
            steps: await steps,
            distanceMeteres: await distance,
            activeEnergyKcal: await energy,
            date: startOfDay
        )
    }
    
    /// This func returs the cumulative sum of a quantity type from a given start date to now
    ///
    private func sumQuantity(
        _ type: HKQuantityType,
        unit: HKUnit,
        since start: Date
    ) async -> Double {
        return await withCheckedContinuation { continuation in
            let timePredicate = HKQuery.predicateForSamples(withStart: start, end: Date())

            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: timePredicate,
                options: .cumulativeSum,
            ) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    // MARK: - Last Night's Sleep

    /// Reads last night's `sleepAnalysis` samples and sums only the "asleep"
    /// stages. Sleep is a *category* type, not a quantity, so there is nothing
    /// for HKStatisticsQuery to sum — we fetch the samples and add up their
    /// durations ourselves.
    public func refreshLastNightSleep() async {
        let calendar = Calendar.current
        let now = Date()

        // A night doesn't line up with a calendar day, so bracket it: 6pm
        // yesterday -> noon today covers a normal night either side of midnight.
        let noonToday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let sixPMYesterday = calendar.date(byAdding: .hour, value: -18, to: noonToday) ?? now

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let timePredicate = HKQuery.predicateForSamples(withStart: sixPMYesterday, end: noonToday)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: timePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil // Default data will be return in Desc order
            ) { _, results, _ in // results is an array of samples; (HKSamples) -> quantity, category, charactestic
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }

            store.execute(query)
        }

        // "In bed" and "awake" samples overlap the asleep ones, so counting
        // every sample would badly overstate the night.
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        let totalAsleep = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        sleep = SleepSummary(asleepSeconds: totalAsleep, date: calendar.startOfDay(for: now))
    }

    // MARK: - 7-Day Active Energy Trend

    /// Builds a daily active-energy collection for the last 7 days with
    /// `HKStatisticsCollectionQuery` — one query that buckets by interval,
    /// rather than seven separate HKStatisticsQuery calls.
    public func refreshEnergyTrend() async {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: Date())

        guard let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) else { return }

        let trend: [EnergyTrendPoint] = await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.day = 1 // one bucket per day

            let timePredicate = HKQuery.predicateForSamples(withStart: startDay, end: Date())

            let query = HKStatisticsCollectionQuery(
                quantityType: energyType,
                quantitySamplePredicate: timePredicate,
                options: .cumulativeSum,
                anchorDate: startDay, // buckets line up with midnight
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, _ in
                var points: [EnergyTrendPoint] = []

                // enumerateStatistics walks every day in the window, including
                // the ones with no samples, so the chart has no gaps.
                collection?.enumerateStatistics(from: startDay, to: Date()) { stats, _ in
                    let kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    points.append(EnergyTrendPoint(day: stats.startDate, activeEnergyKcal: kcal))
                }

                continuation.resume(returning: points)
            }

            store.execute(query)
        }

        energyTrend = trend
    }

    // MARK: - Writing a Workout

    /// Saves a finished activity to HealthKit as an `HKWorkout` via
    /// `HKWorkoutBuilder`. Once this returns, the workout is visible in the
    /// Health app — which is the easiest way to prove the write worked.
    ///
    /// The builder has a required order: begin -> add samples -> end -> finish.
    public func save(_ record: WorkoutRecord, activity: HKWorkoutActivityType = .walking) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: .local() // this device, for provenance in the Health app
        )

        try await builder.beginCollection(at: record.start)

        // The workout is just an envelope; the energy and distance have to be
        // attached as their own samples to show up in the Health app.
        var samples: [HKSample] = []

        if record.activeEnergyKcal > 0 {
            samples.append(
                HKCumulativeQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: record.activeEnergyKcal),
                    start: record.start,
                    end: record.end
                )
            )
        }

        if record.distanceMeters > 0 {
            samples.append(
                HKCumulativeQuantitySample(
                    type: distanceType,
                    quantity: HKQuantity(unit: .meter(), doubleValue: record.distanceMeters),
                    start: record.start,
                    end: record.end
                )
            )
        }

        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        try await builder.endCollection(at: record.end)
        _ = try await builder.finishWorkout()
    }
    
    // MARK: - Live Vitals
    public func startLiveHeartUpdates() {
        guard currentAuthStatus == .authorized, openLiveQueries.isEmpty else { return }
        streamHeartRateData()
        Task {
            await refreshTodayVitals()
        }
    }
    
    public func refreshTodayVitals() async  {
        let startofDay = Calendar.current.startOfDay(for: Date())
        async let steps = sumQuantity(stepsType, unit: .count(), since: startofDay)
        async let energy = sumQuantity(energyType, unit: .kilocalorie(), since: startofDay)
        
        liveVitals.steps = await steps
        liveVitals.activeEnergyKcal = await energy
    }
    
    private func streamHeartRateData() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: nil
        )
        
        let dataHandler: @Sendable (
            HKAnchoredObjectQuery,
            [HKSample]?, // New or Update Data
            [HKDeletedObject]?, // Deletion of data points
            HKQueryAnchor?,
            Error?
        ) -> Void = { [weak self] _, samples, _,_,_ in
            guard let latest = (samples as? [HKQuantitySample])?.last else { return }
            let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            
            Task { @MainActor in
                self?.liveVitals.heartRateBPM = bpm
            }
        }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: dataHandler
        )
        query.updateHandler = dataHandler
        
        store.execute(query)
        
        openLiveQueries.append(query)
    }
    
    public func stopLiveQueries() {
        openLiveQueries.forEach { store.stop($0) }
        openLiveQueries.removeAll()
    }
    
}
