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
        case startTime = "startTime"  // Authoritative start time from initiating device
        case error = "error"
        case intervalData = "intervalData"
        case heartRate = "heartRate"
        case modeRaw = "modeRaw"
        case intervalProgramRaw = "intervalProgramRaw"
        case zoneLow = "zoneLow"
        case zoneHigh = "zoneHigh"
        case streakCurrent = "streakCurrent"
        case streakLongest = "streakLongest"
        case dailyGoal = "dailyGoal"
        case availableShields = "availableShields"
        case todayCalories = "todayCalories"
        case calorieGoal = "calorieGoal"
    }

    // MARK: - Commands (iPhone → Watch)

    enum Command: String, Codable {
        case startWorkout = "startWorkout"
        case pauseWorkout = "pauseWorkout"
        case resumeWorkout = "resumeWorkout"
        case endWorkout = "endWorkout"
        case syncState = "syncState"
        case phaseChangeHaptic = "phaseChangeHaptic"
        case countdownWarningHaptic = "countdownWarningHaptic"
        case milestoneHaptic = "milestoneHaptic"
        case syncStreakInfo = "syncStreakInfo"
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
        case fatBurnOutOfRangeLow = "fatBurnOutOfRangeLow"
        case fatBurnOutOfRangeHigh = "fatBurnOutOfRangeHigh"
    }

    // MARK: - Create Messages

    static func startWorkout(
        walkId: UUID,
        startTime: Date? = nil,
        intervalData: IntervalTransferData? = nil,
        modeRaw: String? = nil,
        intervalProgramRaw: String? = nil,
        zoneLow: Int? = nil,
        zoneHigh: Int? = nil
    ) -> [String: Any] {
        var message: [String: Any] = [
            Key.command.rawValue: Command.startWorkout.rawValue,
            Key.walkId.rawValue: walkId.uuidString,
            Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]

        // Include the authoritative start time from initiating device
        if let startTime {
            message[Key.startTime.rawValue] = startTime.timeIntervalSince1970
        }

        if let intervalData = intervalData,
           let encoded = try? JSONEncoder().encode(intervalData) {
            message[Key.intervalData.rawValue] = encoded
        }
        if let modeRaw {
            message[Key.modeRaw.rawValue] = modeRaw
        }
        if let intervalProgramRaw {
            message[Key.intervalProgramRaw.rawValue] = intervalProgramRaw
        }
        if let zoneLow {
            message[Key.zoneLow.rawValue] = zoneLow
        }
        if let zoneHigh {
            message[Key.zoneHigh.rawValue] = zoneHigh
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
