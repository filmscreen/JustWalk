//
//  APIUsageTracker.swift
//  JustWalk
//
//  Tracks Gemini API usage for rate limiting and analytics
//

import Foundation
import os.log

private let apiUsageLogger = Logger(subsystem: "onworldtech.JustWalk", category: "APIUsageTracker")

// MARK: - API Usage Data Model

struct APIUsageData: Codable {
    var dailyCounts: [String: Int]  // dateString -> count
    var lastResetDate: Date

    static let empty = APIUsageData(dailyCounts: [:], lastResetDate: Date())

    /// Generate a date key in format "yyyy-MM-dd"
    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - API Usage Tracker

@MainActor
final class APIUsageTracker: ObservableObject {
    static let shared = APIUsageTracker()

    // Configuration
    private let dailyLimit = 100  // Gemini free tier limit (adjust as needed)
    private let warningThreshold = 0.8  // Warn at 80% of limit

    // State
    @Published private(set) var todayCount: Int = 0
    @Published private(set) var isApproachingLimit: Bool = false

    private let defaults = UserDefaults.standard
    private let storageKey = "api_usage_data"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let calendar = Calendar.current

    private var usageData: APIUsageData

    private init() {
        // Load persisted data
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? decoder.decode(APIUsageData.self, from: data) {
            usageData = decoded
        } else {
            usageData = .empty
        }

        // Clean up old data (keep last 30 days)
        cleanupOldData()

        // Update today's count
        todayCount = getTodayCount()
        updateWarningState()

        apiUsageLogger.info("APIUsageTracker initialized. Today's count: \(self.todayCount)")
    }

    // MARK: - Public API

    /// Record an API call
    func recordAPICall() {
        let key = APIUsageData.dateKey(for: Date())
        usageData.dailyCounts[key, default: 0] += 1
        todayCount = usageData.dailyCounts[key] ?? 0

        save()
        updateWarningState()

        apiUsageLogger.info("API call recorded. Today's count: \(self.todayCount)")
    }

    /// Get the count for today
    func getTodayCount() -> Int {
        let key = APIUsageData.dateKey(for: Date())
        return usageData.dailyCounts[key] ?? 0
    }

    /// Get the count for a specific date
    func getCount(for date: Date) -> Int {
        let key = APIUsageData.dateKey(for: date)
        return usageData.dailyCounts[key] ?? 0
    }

    /// Get total API calls over a period
    func getTotalCalls(forDays days: Int) -> Int {
        let today = calendar.startOfDay(for: Date())
        var total = 0

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            total += getCount(for: date)
        }

        return total
    }

    /// Get average daily calls over a period
    func getAverageDailyCalls(forDays days: Int) -> Double {
        let total = getTotalCalls(forDays: days)
        return days > 0 ? Double(total) / Double(days) : 0
    }

    /// Check if we're approaching the daily limit
    var isNearLimit: Bool {
        Double(todayCount) >= Double(dailyLimit) * warningThreshold
    }

    /// Check if we've exceeded the daily limit
    var isOverLimit: Bool {
        todayCount >= dailyLimit
    }

    /// Remaining calls for today
    var remainingCalls: Int {
        max(0, dailyLimit - todayCount)
    }

    /// Usage percentage for today (0.0 to 1.0+)
    var usagePercentage: Double {
        Double(todayCount) / Double(dailyLimit)
    }

    /// Get usage history for analytics (last N days)
    func getUsageHistory(days: Int) -> [(date: Date, count: Int)] {
        let today = calendar.startOfDay(for: Date())
        var history: [(date: Date, count: Int)] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            let count = getCount(for: date)
            history.append((date: date, count: count))
        }

        return history
    }

    // MARK: - Private Methods

    private func save() {
        if let data = try? encoder.encode(usageData) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func updateWarningState() {
        isApproachingLimit = isNearLimit
    }

    /// Remove data older than 30 days to prevent unbounded storage growth
    private func cleanupOldData() {
        let today = calendar.startOfDay(for: Date())
        guard let cutoffDate = calendar.date(byAdding: .day, value: -30, to: today) else {
            return
        }

        let cutoffKey = APIUsageData.dateKey(for: cutoffDate)
        var cleaned = false

        for key in usageData.dailyCounts.keys {
            if key < cutoffKey {
                usageData.dailyCounts.removeValue(forKey: key)
                cleaned = true
            }
        }

        if cleaned {
            save()
            apiUsageLogger.info("Cleaned up old API usage data")
        }
    }

    /// Reset today's count (for testing purposes)
    func resetTodayCount() {
        let key = APIUsageData.dateKey(for: Date())
        usageData.dailyCounts[key] = 0
        todayCount = 0
        save()
        updateWarningState()
        apiUsageLogger.info("Today's API usage count reset")
    }

    /// Clear all usage data (for testing/debug)
    func clearAllData() {
        usageData = .empty
        todayCount = 0
        isApproachingLimit = false
        save()
        apiUsageLogger.info("All API usage data cleared")
    }
}
