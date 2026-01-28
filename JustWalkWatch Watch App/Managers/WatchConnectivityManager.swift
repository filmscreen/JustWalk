import Foundation
import Combine
import WatchConnectivity

/// Manages communication with iPhone from Apple Watch
final class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = WatchConnectivityManager()

    // MARK: - Published State
    @Published private(set) var isPhoneReachable = false

    // MARK: - Callbacks
    var onStartWorkoutCommand: ((UUID, IntervalTransferData?) -> Void)?
    var onPauseWorkoutCommand: (() -> Void)?
    var onResumeWorkoutCommand: (() -> Void)?
    var onEndWorkoutCommand: (() -> Void)?

    // MARK: - Private
    private var session: WCSession?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else { return }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send to iPhone

    func sendWorkoutStarted(walkId: UUID) {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutStarted.rawValue,
            WatchMessage.Key.walkId.rawValue: walkId.uuidString
        ]
        sendMessage(message)
    }

    func sendWorkoutPaused() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutPaused.rawValue
        ]
        sendMessage(message)
    }

    func sendWorkoutResumed() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutResumed.rawValue
        ]
        sendMessage(message)
    }

    func sendWorkoutEnded(summary: WorkoutSummaryData) {
        guard let data = try? JSONEncoder().encode(summary) else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutEnded.rawValue,
            WatchMessage.Key.workoutData.rawValue: data
        ]
        sendMessage(message)
    }

    func sendStatsUpdate(stats: WorkoutLiveStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.statsUpdate.rawValue,
            WatchMessage.Key.workoutData.rawValue: data
        ]

        // Use unreliable send for frequent updates (don't queue)
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    func sendWorkoutError(_ error: String) {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutError.rawValue,
            WatchMessage.Key.error.rawValue: error
        ]
        sendMessage(message)
    }

    /// Send heart rate update to iPhone for Fat Burn Zone real-time monitoring
    func sendHeartRateUpdate(bpm: Int) {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.heartRateUpdate.rawValue,
            WatchMessage.Key.heartRate.rawValue: bpm
        ]
        // Use unreliable send for frequent HR updates (don't queue if not reachable)
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Private

    private func sendMessage(_ message: [String: Any]) {
        guard let session = session else { return }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send message to iPhone: \(error)")
                // Fallback to transfer
                session.transferUserInfo(message)
            }
        } else {
            // Queue for delivery
            session.transferUserInfo(message)
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let commandString = message[WatchMessage.Key.command.rawValue] as? String,
              let command = WatchMessage.Command(rawValue: commandString) else { return }

        DispatchQueue.main.async {
            switch command {
            case .startWorkout:
                if let walkIdString = message[WatchMessage.Key.walkId.rawValue] as? String,
                   let walkId = UUID(uuidString: walkIdString) {
                    // Parse interval data if present
                    var intervalData: IntervalTransferData?
                    if let data = message[WatchMessage.Key.intervalData.rawValue] as? Data {
                        intervalData = try? JSONDecoder().decode(IntervalTransferData.self, from: data)
                    }
                    self.onStartWorkoutCommand?(walkId, intervalData)
                }

            case .pauseWorkout:
                self.onPauseWorkoutCommand?()

            case .resumeWorkout:
                self.onResumeWorkoutCommand?()

            case .endWorkout:
                self.onEndWorkoutCommand?()

            case .syncState:
                // Handle state sync request
                break
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["received": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleReceivedMessage(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Handle app context if needed
        // This can trigger workout start even if app was not running
        handleReceivedMessage(applicationContext)
    }
}
