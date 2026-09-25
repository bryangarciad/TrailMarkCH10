import Foundation
import Observation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// One WatchConnectivity wrapper used by BOTH sides (iPhone + Watch). Each payload
// gets the transfer type that fits it:
//
//   • applicationContext — "latest state" (today's summary). Coalesced: only the
//                          newest value survives, older ones are dropped. Cheap,
//                          ideal for a glanceable mirror.
//   • transferUserInfo   — queued, guaranteed delivery of discrete records (a
//                          finished workout / journey). Every item arrives, in
//                          order, even if the other app was asleep or relaunched.
//   • transferFile       — large binary payloads (a voice memo) plus metadata.
//                          Queued and delivered in the background like userInfo.
//
// sendMessage (live) is deliberately avoided: it only works while the counterpart
// is reachable RIGHT NOW. A phone in a pocket is backgrounded, so the message
// fails instead of waiting in a queue.
@MainActor
@Observable
public final class ConnectivityManager: NSObject {

    public static let shared = ConnectivityManager()

    public private(set) var isReachable = false
    public private(set) var isActivated = false
    public private(set) var lastError: String?

    /// Today's summary mirrored from the counterpart (shown on the wrist).
    public private(set) var mirroredSummary: ActivitySummary?

    // Sender-side queue state, driven by the didFinish callbacks below.

    /// Memos whose file transfer is queued or in flight.
    public private(set) var pendingMemoIDs: Set<UUID> = []
    /// Memos whose last transfer failed. The system drops failed transfers from its
    /// queue, so these are neither pending nor delivered until they're resent.
    public private(set) var failedMemoIDs: Set<UUID> = []
    /// Queued userInfo records (workouts / journeys) not yet delivered.
    public private(set) var pendingRecordCount = 0

    // App-supplied sinks. Each app wires these once at launch.
    public var onReceiveWorkout: ((WorkoutRecord) -> Void)?
    public var onReceiveJourney: ((Journey) -> Void)?
    /// Called when a media file arrives: a copy of the file we own, plus the memo
    /// metadata. The handler is expected to move it in and `register` it with the
    /// MediaStore.
    public var onReceiveMediaFile: ((URL, MediaMemo) -> Void)?

    private enum PayloadType: String {
        case summary, workout, journey, memo
    }

    #if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
    #endif

    /// Both sides must set the delegate and activate before anything can be sent
    /// or received. Call once at launch.
    public func activate() {
        #if canImport(WatchConnectivity)
        guard let session else { return }
        session.delegate = self
        session.activate()
        #endif
    }

    // MARK: - Sending

    /// True only when there's actually a counterpart to talk to. Without this,
    /// sending from a phone with no paired watch (e.g. a lone Simulator) throws
    /// `WCErrorCodeDeviceNotPaired` and spams the console, so we skip instead.
    private var canSend: Bool {
        #if canImport(WatchConnectivity)
        guard let session, session.activationState == .activated else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return true
        #endif
        #else
        return false
        #endif
    }

    /// Mirror today's headline metrics to the counterpart (coalesced latest state).
    public func sync(summary: ActivitySummary) {
        #if canImport(WatchConnectivity)
        guard canSend, let data = try? JSONEncoder().encode(summary) else { return }
        try? session?.updateApplicationContext([
            "type": PayloadType.summary.rawValue,
            "payload": data
        ])
        #endif
    }

    /// Queue a finished workout for guaranteed delivery.
    public func sync(workout: WorkoutRecord) {
        send(.workout, encoding: workout)
    }

    /// Queue a whole journey (route + memo IDs + workout) for guaranteed delivery.
    public func sync(journey: Journey) {
        send(.journey, encoding: journey)
    }

    /// Transfer a media file with its memo metadata attached ("pocket sync").
    /// Also used to resend a failed memo: the phone replaces by ID, so no duplicate.
    public func transfer(memo: MediaMemo, fileURL: URL) {
        #if canImport(WatchConnectivity)
        // Never queued, so it would otherwise look delivered. Mark it failed so the
        // user can resend once the counterpart is back.
        guard canSend else {
            failedMemoIDs.insert(memo.id)
            lastError = "Counterpart not available — memo not sent"
            return
        }
        // Metadata must be property-list types, so the memo travels as a JSON string.
        guard let data = try? JSONEncoder().encode(memo),
              let json = String(data: data, encoding: .utf8) else { return }
        session?.transferFile(fileURL, metadata: [
            "type": PayloadType.memo.rawValue,
            "memo": json,
            // Plain ID so the sender can match the finished transfer back to the memo.
            "memoID": memo.id.uuidString
        ])
        failedMemoIDs.remove(memo.id)
        pendingMemoIDs.insert(memo.id)
        #endif
    }

    private func send<T: Encodable>(_ type: PayloadType, encoding value: T) {
        #if canImport(WatchConnectivity)
        guard canSend, let data = try? JSONEncoder().encode(value) else { return }
        session?.transferUserInfo([
            "type": type.rawValue,
            "payload": data
        ])
        pendingRecordCount += 1
        #endif
    }

    #if canImport(WatchConnectivity)
    /// Memo IDs of the file transfers still in the system queue.
    nonisolated private static func outstandingMemoIDs(in session: WCSession) -> Set<UUID> {
        Set(session.outstandingFileTransfers.compactMap {
            ($0.file.metadata?["memoID"] as? String).flatMap(UUID.init(uuidString:))
        })
    }
    #endif
}

#if canImport(WatchConnectivity)
extension ConnectivityManager: WCSessionDelegate {

    // WCSession calls its delegate on a background queue, so every callback is
    // nonisolated and hops to the MainActor before touching state.

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        let message = error?.localizedDescription
        // The queue survives relaunch, so rebuild the pending state from what the
        // system still has outstanding rather than starting from empty.
        let pendingMemos = Self.outstandingMemoIDs(in: session)
        let pendingRecords = session.outstandingUserInfoTransfers.count
        Task { @MainActor in
            self.isActivated = (state == .activated)
            self.lastError = message
            self.pendingMemoIDs = pendingMemos
            self.pendingRecordCount = pendingRecords
        }
    }

    // Sender side: a queued file finished (delivered or failed).
    nonisolated public func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        // WCSessionFileTransfer isn't Sendable: pull out the values first.
        let memoID = (fileTransfer.file.metadata?["memoID"] as? String).flatMap(UUID.init(uuidString:))
        let message = error?.localizedDescription
        Task { @MainActor in
            guard let memoID else { return }
            self.pendingMemoIDs.remove(memoID)
            if let message {
                self.failedMemoIDs.insert(memoID)
                self.lastError = message
            }
        }
    }

    // Sender side: a queued userInfo record finished (delivered or failed).
    nonisolated public func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        let message = error?.localizedDescription
        Task { @MainActor in
            self.pendingRecordCount = max(0, self.pendingRecordCount - 1)
            if let message { self.lastError = message }
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    // Latest-state mirror.
    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        handle(dictionary: applicationContext)
    }

    // Queued discrete records.
    nonisolated public func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        handle(dictionary: userInfo)
    }

    // Incoming media file.
    nonisolated public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Read the metadata here: `[String: Any]` isn't Sendable, so only the
        // Strings we actually need may cross into the MainActor task below.
        let metadata = file.metadata ?? [:]
        let type = metadata["type"] as? String
        let json = metadata["memo"] as? String

        // Copy out of the inbox IMMEDIATELY. The system deletes `file.fileURL` as
        // soon as this method returns, so by the time the Task below runs it would
        // already be gone.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(file.fileURL.lastPathComponent)
        try? FileManager.default.removeItem(at: tempURL)
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: tempURL)
        } catch {
            let message = error.localizedDescription
            Task { @MainActor in self.lastError = message }
            return
        }

        Task { @MainActor in
            guard type == PayloadType.memo.rawValue,
                  let data = json?.data(using: .utf8),
                  let memo = try? JSONDecoder().decode(MediaMemo.self, from: data) else { return }
            self.onReceiveMediaFile?(tempURL, memo)
        }
    }

    private nonisolated func handle(dictionary: [String: Any]) {
        guard let typeString = dictionary["type"] as? String,
              let type = PayloadType(rawValue: typeString),
              let data = dictionary["payload"] as? Data else { return }
        Task { @MainActor in
            switch type {
            case .summary:
                if let summary = try? JSONDecoder().decode(ActivitySummary.self, from: data) {
                    self.mirroredSummary = summary
                }
            case .workout:
                if let workout = try? JSONDecoder().decode(WorkoutRecord.self, from: data) {
                    self.onReceiveWorkout?(workout)
                }
            case .journey:
                if let journey = try? JSONDecoder().decode(Journey.self, from: data) {
                    self.onReceiveJourney?(journey)
                }
            case .memo:
                break // memos arrive as files, handled above
            }
        }
    }

    #if os(iOS)
    // iOS only: the phone can switch between paired watches.
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so a newly-paired watch can still talk to us.
        session.activate()
    }
    #endif
}
#endif
