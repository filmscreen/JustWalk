//
//  WatchMessage.swift
//  JustWalk
//
//  Messages sent between iPhone and Watch
//

import Foundation

enum WatchMessage {

    // MARK: - Message Keys

    enum Key: String {
        case command = "command"
        case walkId = "walkId"
        case workoutData = "workoutData"
        case timestamp = "timestamp"
        case error = "error"
        case intervalData = "intervalData"
        case heartRate = "heartRate"
    }

    // MARK: - Commands (iPhone → Watch)

    enum Command: String, Codable {
        case startWorkout = "startWorkout"
        case pauseWorkout = "pauseWorkout"
        case resumeWorkout = "resumeWorkout"
        case endWorkout = "endWorkout"
        case syncState = "syncState"
    }

    // MARK: - Events (Watch → iPhone)

    enum Event: String, Codable {
        case workoutStarted = "workoutStarted"
        case workoutPaused = "workoutPaused"
        case workoutResumed = "workoutResumed"
        case workoutEnded = "workoutEnded"
        case workoutError = "workoutError"
        case heartRateUpdate = "heartRateUpdate"
        case statsUpdate = "statsUpdate"
    }

    // MARK: - Create Messages

    static func startWorkout(walkId: UUID, intervalData: IntervalTransferData? = nil) -> [String: Any] {
        var message: [String: Any] = [
            Key.command.rawValue: Command.startWorkout.rawValue,
            Key.walkId.rawValue: walkId.uuidString,
            Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]

        if let intervalData = intervalData,
           let encoded = try? JSONEncoder().encode(intervalData) {
            message[Key.intervalData.rawValue] = encoded
        }

        return message
    }

    static func endWorkout(walkId: UUID) -> [String: Any] {
        return [
            Key.command.rawValue: Command.endWorkout.rawValue,
            Key.walkId.rawValue: walkId.uuidString,
            Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]
    }

    static func workoutEnded(data: WorkoutSummaryData) -> [String: Any] {
        return [
            Key.command.rawValue: Event.workoutEnded.rawValue,
            Key.workoutData.rawValue: (try? JSONEncoder().encode(data)) as Any,
            Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]
    }
}
