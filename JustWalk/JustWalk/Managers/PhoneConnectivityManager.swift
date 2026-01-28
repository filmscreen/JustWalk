//
//  PhoneConnectivityManager.swift
//  JustWalk
//
//  Manages communication with Apple Watch from iPhone
//

import Foundation
import WatchConnectivity
import Combine

final class PhoneConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = PhoneConnectivityManager()

    // MARK: - Published State

    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isWatchReachable = false
    @Published private(set) var watchWorkoutState: WorkoutState = .idle
    @Published private(set) var latestWatchStats: WorkoutLiveStats?

    // MARK: - Callbacks

    var onWorkoutStartedOnWatch: ((UUID) -> Void)?
    var onWorkoutEndedOnWatch: ((WorkoutSummaryData) -> Void)?
    var onWatchError: ((String) -> Void)?

    // MARK: - Private

    private var session: WCSession?
    private var pendingMessages: [[String: Any]] = []
    private var currentWalkId: UUID?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Public API

    /// Check if we can communicate with Watch
    var canCommunicateWithWatch: Bool {
        guard let session = session else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    /// Check if Watch is immediately reachable
    var isWatchImmediatelyReachable: Bool {
        session?.isReachable ?? false
    }

    /// Start workout on Watch (called when iPhone starts a walk)
    func startWorkoutOnWatch(walkId: UUID, intervalData: IntervalTransferData? = nil, completion: ((Bool) -> Void)? = nil) {
        self.currentWalkId = walkId

        let message = WatchMessage.startWorkout(walkId: walkId, intervalData: intervalData)
        sendMessage(message, requiresImmediateDelivery: true) { success in
            if !success {
                // Fallback: update application context
                self.updateApplicationContext(workoutState: .active, walkId: walkId)
            }
            completion?(success)
        }
    }

    /// Pause workout on Watch
    func pauseWorkoutOnWatch() {
        guard let walkId = currentWalkId else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.pauseWorkout.rawValue,
            WatchMessage.Key.walkId.rawValue: walkId.uuidString
        ]
        sendMessage(message, requiresImmediateDelivery: true)
    }

    /// Resume workout on Watch
    func resumeWorkoutOnWatch() {
        guard let walkId = currentWalkId else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.resumeWorkout.rawValue,
            WatchMessage.Key.walkId.rawValue: walkId.uuidString
        ]
        sendMessage(message, requiresImmediateDelivery: true)
    }

    /// End workout on Watch (called when iPhone ends a walk)
    func endWorkoutOnWatch(completion: ((Bool) -> Void)? = nil) {
        guard let walkId = currentWalkId else {
            completion?(false)
            return
        }

        let message = WatchMessage.endWorkout(walkId: walkId)
        sendMessage(message, requiresImmediateDelivery: true) { success in
            if !success {
                // Fallback: update application context
                self.updateApplicationContext(workoutState: .ending, walkId: walkId)
            }
            self.currentWalkId = nil
            completion?(success)
        }
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: [String: Any], requiresImmediateDelivery: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let session = session else {
            completion?(false)
            return
        }

        if session.isReachable && requiresImmediateDelivery {
            // Send interactive message (immediate)
            session.sendMessage(message, replyHandler: { _ in
                completion?(true)
            }, errorHandler: { error in
                print("Failed to send message: \(error.localizedDescription)")
                // Queue for later if failed
                self.pendingMessages.append(message)
                completion?(false)
            })
        } else {
            // Use transferUserInfo for guaranteed delivery (not immediate)
            session.transferUserInfo(message)
            completion?(true) // Will be delivered eventually
        }
    }

    private func updateApplicationContext(workoutState: WorkoutState, walkId: UUID?) {
        guard let session = session else { return }

        let context = AppContext(
            workoutState: workoutState,
            currentWalkId: walkId,
            isPro: SubscriptionManager.shared.isPro,
            lastSyncTime: Date()
        )

        do {
            let data = try JSONEncoder().encode(context)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                try session.updateApplicationContext(dict)
            }
        } catch {
            print("Failed to update application context: \(error)")
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let commandString = message[WatchMessage.Key.command.rawValue] as? String else { return }

        // Handle events from Watch
        if let event = WatchMessage.Event(rawValue: commandString) {
            switch event {
            case .workoutStarted:
                if let walkIdString = message[WatchMessage.Key.walkId.rawValue] as? String,
                   let walkId = UUID(uuidString: walkIdString) {
                    DispatchQueue.main.async {
                        self.watchWorkoutState = .active
                        self.onWorkoutStartedOnWatch?(walkId)
                    }
                }

            case .workoutPaused:
                DispatchQueue.main.async {
                    self.watchWorkoutState = .paused
                }

            case .workoutResumed:
                DispatchQueue.main.async {
                    self.watchWorkoutState = .active
                }

            case .workoutEnded:
                if let data = message[WatchMessage.Key.workoutData.rawValue] as? Data,
                   let summary = try? JSONDecoder().decode(WorkoutSummaryData.self, from: data) {
                    DispatchQueue.main.async {
                        self.watchWorkoutState = .idle
                        self.currentWalkId = nil
                        self.onWorkoutEndedOnWatch?(summary)
                    }
                }

            case .statsUpdate:
                if let data = message[WatchMessage.Key.workoutData.rawValue] as? Data,
                   let stats = try? JSONDecoder().decode(WorkoutLiveStats.self, from: data) {
                    DispatchQueue.main.async {
                        self.latestWatchStats = stats
                    }
                }

            case .heartRateUpdate:
                if let hr = message[WatchMessage.Key.heartRate.rawValue] as? Int {
                    DispatchQueue.main.async {
                        FatBurnZoneManager.shared.updateHeartRate(hr)
                    }
                }

            case .workoutError:
                if let error = message[WatchMessage.Key.error.rawValue] as? String {
                    DispatchQueue.main.async {
                        self.onWatchError?(error)
                    }
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }

        // Send any pending messages
        if activationState == .activated && session.isReachable {
            pendingMessages.forEach { sendMessage($0, requiresImmediateDelivery: false) }
            pendingMessages.removeAll()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS only
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // iOS only — reactivate
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }

        // Watch reconnected during an active walk — sync state
        if session.isReachable && watchWorkoutState == .active, let walkId = currentWalkId {
            updateApplicationContext(workoutState: .active, walkId: walkId)
        }
    }

    // Receive interactive message
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["received": true])
    }

    // Receive transferred user info (guaranteed delivery)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleReceivedMessage(userInfo)
    }

    // Receive application context update
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Handle context update from Watch if needed
    }
}
