import Foundation
import CoreMotion
import Observation

@MainActor
@Observable
public final class MotionManager {
    
    public enum Activity: String, Sendable {
        case stationary, walking, running, cycling, unknown
        
        public var label: String { rawValue.capitalized }
        
        public var symbolName: String  {
            switch self {
            case .stationary: return "figure.stand"
            case .walking: return "figure.walk"
            case .running: return "figure.run"
            case .cycling: return "bicycle"
            case .unknown: return "questionmark"
            }
        }
    }
    
    
    public private(set) var stepsToday: Int = 0
    public private(set) var cadence: Double = 0
    public private(set) var activity: Activity = .unknown
    public private(set) var acceleration: (Double, Double, Double) = (0, 0, 0)
    
    private let pedometer = CMPedometer() // This interface is used to get steps, cadence, flights climbed, etc
    private let activityManager = CMMotionActivityManager() // Approximate current activity
    private let motionManager = CMMotionManager() // This interfaces is to get raw data from Acc, Giro, and Magnetometer
    
    public init() {}
    
    public var isShakeDetected: Bool {
        accMagnitude >= 2.4 // 2.4 is Medium sensibility for shake detection
    }
    
    public var accMagnitude: Double {
        (acceleration.0 * acceleration.0 + acceleration.1 * acceleration.1 + acceleration.2 * acceleration.2).squareRoot()
    }
    
    // MARK: - Availability Checks
    
    public static var isPedometersAvailable: Bool {
        return CMPedometer.isStepCountingAvailable()
    }
    
    public static var isActivityAvailable: Bool {
        return CMMotionActivityManager.isActivityAvailable()
    }

    // MARK: - Data Retrival
    public func startActivityUpdate() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        activityManager.startActivityUpdates(to: .main) { [weak self] activity  in
            guard let activity else { return }

            let resolvedACtivity: Activity
            
            if activity.walking { resolvedACtivity = .walking }
            else if activity.running { resolvedACtivity = .running }
            else if activity.cycling { resolvedACtivity = .cycling }
            else if activity.stationary { resolvedACtivity = .stationary }
            else { resolvedACtivity = .unknown }
            
            self?.activity = resolvedACtivity
        }
    }
    
    public func startAccelerometerUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1 // tenth of 1 = 10hz
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let data = motion?.userAcceleration else { return }
            
            self?.acceleration = (data.x, data.y, data.z)
        }
    }
    
    public func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let data else { return }
            
            let steps = data.numberOfSteps.intValue
            let cadence = (data.currentCadence?.doubleValue ?? 0) * 60 // cadence in minutes
            
            Task { @MainActor in
                self?.stepsToday = steps
                self?.cadence = cadence
            }
        }
    }
    
    public func stopAllUpdates() {
        pedometer.stopUpdates()
    }
}
