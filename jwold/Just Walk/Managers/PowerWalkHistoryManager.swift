//
//  PowerWalkHistoryManager.swift
//  Just Walk
//
//  Persists completed Power Walk sessions.
//  Provides weekly statistics and session history.
//

import Foundation
import Combine

/// Persists completed Power Walk sessions
@MainActor
final class PowerWalkHistoryManager: ObservableObject {
    static let shared = PowerWalkHistoryManager()

    private let defaults = UserDefaults.standard
    private let historyKey = "powerWalk_sessionHistory"
    private let maxHistoryCount = 100

    // MARK: - Published Properties

    @Published private(set) var recentSessions: [PowerWalkSessionSummary] = []

    // MARK: - Initialization

    private init() {
        loadHistory()
    }

    // MARK: - Session Recording

    /// Record a completed Power Walk session
    func recordSession(_ summary: PowerWalkSessionSummary) {
        recentSessions.insert(summary, at: 0)

        // Trim to max count
        if recentSessions.count > maxHistoryCount {
            recentSessions = Array(recentSessions.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    /// Update an existing session (e.g., to add steps/distance after HealthKit sync)
    func updateSession(
        at index: Int,
        steps: Int? = nil,
        distance: Double? = nil,
        averageHeartRate: Double? = nil,
        activeCalories: Double? = nil
    ) {
        guard index < recentSessions.count else { return }

        var session = recentSessions[index]
        if let steps = steps { session.steps = steps }
        if let distance = distance { session.distance = distance }
        if let averageHeartRate = averageHeartRate { session.averageHeartRate = averageHeartRate }
        if let activeCalories = activeCalories { session.activeCalories = activeCalories }

        recentSessions[index] = session
        saveHistory()
    }

    // MARK: - Statistics

    /// Sessions from the last 7 days
    var thisWeekSessions: [PowerWalkSessionSummary] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return recentSessions.filter { $0.startTime >= weekAgo }
    }

    /// Number of Power Walks completed this week
    var powerWalksThisWeek: Int {
        thisWeekSessions.count
    }

    /// Total steps from Power Walks this week
    var stepsThisWeek: Int {
        thisWeekSessions.reduce(0) { $0 + $1.steps }
    }

    /// Total distance (meters) from Power Walks this week
    var distanceThisWeek: Double {
        thisWeekSessions.reduce(0) { $0 + $1.distance }
    }

    /// Total duration (seconds) from Power Walks this week
    var durationThisWeek: TimeInterval {
        thisWeekSessions.reduce(0) { $0 + $1.totalDuration }
    }

    /// Average completion rate this week (0.0 to 1.0)
    var averageCompletionRateThisWeek: Double {
        guard !thisWeekSessions.isEmpty else { return 0 }
        let totalCompletion = thisWeekSessions.reduce(0.0) { $0 + $1.completionPercentage }
        return totalCompletion / Double(thisWeekSessions.count)
    }

    /// Sessions from today
    var todaySessions: [PowerWalkSessionSummary] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        return recentSessions.filter { $0.startTime >= startOfToday }
    }

    /// Number of Power Walks completed today
    var powerWalksToday: Int {
        todaySessions.count
    }

    /// Most frequently used preset
    var favoritePreset: PowerWalkPreset? {
        let presetCounts = recentSessions.reduce(into: [String: Int]()) { counts, session in
            counts[session.workout.preset.id, default: 0] += 1
        }
        guard let mostUsedId = presetCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        return PowerWalkPreset.preset(forId: mostUsedId)
    }

    /// Average session duration (in seconds)
    var averageSessionDuration: TimeInterval {
        guard !recentSessions.isEmpty else { return 0 }
        let totalDuration = recentSessions.reduce(0.0) { $0 + $1.totalDuration }
        return totalDuration / Double(recentSessions.count)
    }

    /// Longest streak of consecutive days with Power Walks
    var longestStreak: Int {
        guard !recentSessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedDates = Set(recentSessions.map { calendar.startOfDay(for: $0.startTime) })
            .sorted(by: >)

        var currentStreak = 1
        var maxStreak = 1

        for i in 1..<sortedDates.count {
            let previousDate = sortedDates[i - 1]
            let currentDate = sortedDates[i]

            if let daysBetween = calendar.dateComponents([.day], from: currentDate, to: previousDate).day,
               daysBetween == 1 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }

        return maxStreak
    }

    /// Current streak (consecutive days ending today or yesterday)
    var currentStreak: Int {
        guard !recentSessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let sortedDates = Set(recentSessions.map { calendar.startOfDay(for: $0.startTime) })
            .sorted(by: >)

        // Check if streak is active (session today or yesterday)
        guard let mostRecentDate = sortedDates.first,
              mostRecentDate >= yesterday else {
            return 0
        }

        var streak = 1
        var expectedDate = calendar.date(byAdding: .day, value: -1, to: mostRecentDate)!

        for i in 1..<sortedDates.count {
            let date = sortedDates[i]
            if date == expectedDate {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Cleanup

    /// Remove sessions older than a certain number of days
    func pruneOldSessions(olderThan days: Int = 90) {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let originalCount = recentSessions.count
        recentSessions = recentSessions.filter { $0.startTime >= cutoff }

        if recentSessions.count != originalCount {
            saveHistory()
        }
    }

    /// Clear all session history
    func clearHistory() {
        recentSessions = []
        defaults.removeObject(forKey: historyKey)
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let sessions = try? JSONDecoder().decode([PowerWalkSessionSummary].self, from: data) else {
            return
        }
        recentSessions = sessions
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(recentSessions) else { return }
        defaults.set(data, forKey: historyKey)
    }
}

// MARK: - Formatted Statistics

extension PowerWalkHistoryManager {
    /// Formatted weekly stats for display
    var weeklyStatsFormatted: WeeklyStats {
        WeeklyStats(
            workoutCount: powerWalksThisWeek,
            totalSteps: stepsThisWeek,
            totalDistanceMiles: distanceThisWeek * 0.000621371,
            totalDurationMinutes: Int(durationThisWeek / 60),
            averageCompletion: averageCompletionRateThisWeek
        )
    }

    struct WeeklyStats {
        let workoutCount: Int
        let totalSteps: Int
        let totalDistanceMiles: Double
        let totalDurationMinutes: Int
        let averageCompletion: Double

        var formattedSteps: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: totalSteps)) ?? "\(totalSteps)"
        }

        var formattedDistance: String {
            String(format: "%.1f mi", totalDistanceMiles)
        }

        var formattedDuration: String {
            let hours = totalDurationMinutes / 60
            let minutes = totalDurationMinutes % 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes) min"
            }
        }

        var formattedCompletion: String {
            "\(Int(averageCompletion * 100))%"
        }
    }
}
