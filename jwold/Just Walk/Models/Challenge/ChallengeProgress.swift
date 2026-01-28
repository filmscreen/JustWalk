//
//  ChallengeProgress.swift
//  Just Walk
//
//  User's progress tracking for an active challenge.
//

import Foundation

/// Tracks user's progress on a specific challenge
struct ChallengeProgress: Identifiable, Codable, Equatable {
    /// Unique identifier for this progress instance
    let id: UUID

    /// ID of the challenge this progress tracks
    let challengeId: String

    /// Current status of the challenge
    var status: ChallengeStatus

    /// When the user started the challenge
    var startedAt: Date?

    /// When the challenge was completed (success or failure)
    var completedAt: Date?

    /// Daily progress entries for multi-day challenges
    var dailyProgress: [DailyProgress]

    /// Start time for quick challenges
    var quickChallengeStartTime: Date?

    /// End time for quick challenges
    var quickChallengeEndTime: Date?

    // MARK: - Initialization

    /// Initialize a new progress tracker
    init(
        id: UUID = UUID(),
        challengeId: String,
        status: ChallengeStatus = .available,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        dailyProgress: [DailyProgress] = [],
        quickChallengeStartTime: Date? = nil,
        quickChallengeEndTime: Date? = nil
    ) {
        self.id = id
        self.challengeId = challengeId
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.dailyProgress = dailyProgress
        self.quickChallengeStartTime = quickChallengeStartTime
        self.quickChallengeEndTime = quickChallengeEndTime
    }

    // MARK: - Computed Properties

    /// Number of days where the goal was met
    var daysCompleted: Int {
        dailyProgress.filter { $0.goalMet }.count
    }

    /// Total steps accumulated across all days
    var totalSteps: Int {
        dailyProgress.reduce(0) { $0 + $1.steps }
    }

    /// Check if quick challenge timer has expired
    var isQuickChallengeExpired: Bool {
        guard let endTime = quickChallengeEndTime else { return false }
        return Date() > endTime
    }

    /// Time remaining for quick challenges (in seconds)
    var quickChallengeSecondsRemaining: TimeInterval? {
        guard let endTime = quickChallengeEndTime else { return nil }
        let remaining = endTime.timeIntervalSince(Date())
        return max(0, remaining)
    }

    /// Formatted time remaining string for quick challenges
    var quickChallengeTimeRemainingFormatted: String? {
        guard let seconds = quickChallengeSecondsRemaining else { return nil }
        if seconds <= 0 { return "Time's up!" }

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else if minutes > 0 {
            return "\(minutes)m remaining"
        } else {
            return "Less than 1m remaining"
        }
    }

    /// Get today's progress entry if it exists
    var todayProgress: DailyProgress? {
        dailyProgress.first { $0.isToday }
    }

    /// Progress percentage (0.0 to 1.0)
    func progressPercentage(for challenge: Challenge) -> Double {
        if challenge.isQuickChallenge {
            // For quick challenges, base progress on steps toward target
            guard challenge.dailyStepTarget > 0 else { return 0 }
            return min(1.0, Double(totalSteps) / Double(challenge.dailyStepTarget))
        } else {
            // For multi-day challenges, base progress on days completed
            guard challenge.targetDays > 0 else { return 0 }
            return Double(daysCompleted) / Double(challenge.targetDays)
        }
    }

    // MARK: - Mutations

    /// Start the challenge
    mutating func start(durationHours: Int? = nil) {
        let now = Date()
        startedAt = now
        status = .active

        if let hours = durationHours {
            quickChallengeStartTime = now
            quickChallengeEndTime = Calendar.current.date(byAdding: .hour, value: hours, to: now)
        }
    }

    /// Update progress for today
    mutating func updateTodayProgress(steps: Int, dailyTarget: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let goalMet = steps >= dailyTarget

        if let index = dailyProgress.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            dailyProgress[index].steps = steps
            dailyProgress[index].goalMet = goalMet
            dailyProgress[index].lastUpdated = Date()
        } else {
            let newProgress = DailyProgress(
                date: today,
                steps: steps,
                goalMet: goalMet,
                lastUpdated: Date()
            )
            dailyProgress.append(newProgress)
        }
    }

    /// Mark as completed
    mutating func complete() {
        status = .completed
        completedAt = Date()
    }

    /// Mark as failed
    mutating func fail() {
        status = .failed
        completedAt = Date()
    }

    // MARK: - Equatable

    static func == (lhs: ChallengeProgress, rhs: ChallengeProgress) -> Bool {
        lhs.id == rhs.id
    }
}
