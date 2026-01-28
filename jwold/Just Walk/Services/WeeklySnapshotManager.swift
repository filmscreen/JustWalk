//
//  WeeklySnapshotManager.swift
//  Just Walk
//
//  Lightweight manager for the "Weekly Snapshot" feature.
//  Calculates the "Human Big 4" metrics for a feel-good weekly recap.
//

import Foundation
import Combine

/// The "Human Big 4" metrics for the weekly snapshot
struct WeeklySnapshot: Codable {
    let weekStartDate: Date
    let weekEndDate: Date

    // The Big 4
    let totalSteps: Int
    let percentageChange: Int?  // nil if no previous week data
    let bestDayName: String?
    let bestDaySteps: Int?
    let totalMiles: Int

    // Computed
    var isUp: Bool { (percentageChange ?? 0) > 0 }
    var isDown: Bool { (percentageChange ?? 0) < 0 }

    var formattedSteps: String {
        totalSteps.formatted()
    }

    var dailyAverage: Int {
        totalSteps / 7
    }

    var formattedDailyAverage: String {
        dailyAverage.formatted()
    }
}

@MainActor
final class WeeklySnapshotManager: ObservableObject {

    static let shared = WeeklySnapshotManager()

    @Published private(set) var currentSnapshot: WeeklySnapshot?
    @Published private(set) var isLoading = false
    @Published var shouldShowSnapshot = false
    @Published var hasPendingTile = false

    private let calendar = Calendar.current
    private let snapshotShownKey = "lastWeeklySnapshotShown"
    private let pendingSnapshotKey = "pendingWeeklySnapshot"
    private let pendingWeekStartKey = "pendingSnapshotWeekStart"

    private init() {
        // Load any pending snapshot on init
        loadPendingSnapshot()
    }

    // MARK: - Public API

    /// Check if we should show the weekly snapshot (Monday, not yet shown this week)
    func checkAndPrepareSnapshot() async {
        let today = Date()

        // Skip snapshot for 24 hours after onboarding completes
        // This prevents confusing new users with a meaningless summary
        if let onboardingDate = UserDefaults.standard.object(forKey: "onboardingCompletedDate") as? Date,
           today.timeIntervalSince(onboardingDate) < 86400 { // 24 hours
            return
        }

        // Check if there's already a pending snapshot that's still valid for this week
        if loadPendingSnapshotIfValid() {
            hasPendingTile = true
            return
        }

        // Only auto-trigger on Monday (notification tap uses showSnapshotFromNotification)
        guard calendar.component(.weekday, from: today) == 2 else { return }

        // Check if already shown this week
        if let lastShown = UserDefaults.standard.object(forKey: snapshotShownKey) as? Date,
           calendar.isDate(lastShown, equalTo: today, toGranularity: .weekOfYear) {
            return
        }

        // Calculate and show
        await calculateSnapshot()

        if currentSnapshot != nil {
            savePendingSnapshot()
            shouldShowSnapshot = true
            hasPendingTile = true
        }
    }

    /// Force show snapshot from notification tap (bypasses Monday check)
    func showSnapshotFromNotification() async {
        // Skip Monday check - user explicitly tapped notification
        await calculateSnapshot()

        if currentSnapshot != nil {
            savePendingSnapshot()
            shouldShowSnapshot = true
            hasPendingTile = true
        }
    }

    /// Debug: Show snapshot with fake test data (80k steps, 15% up from last week)
    func showDebugSnapshot() {
        let (lastMonday, lastSunday) = getPreviousWeekRange()

        currentSnapshot = WeeklySnapshot(
            weekStartDate: lastMonday,
            weekEndDate: lastSunday,
            totalSteps: 80_000,
            percentageChange: 15,
            bestDayName: "Saturday",
            bestDaySteps: 14_523,
            totalMiles: 40
        )

        savePendingSnapshot()
        shouldShowSnapshot = true
        hasPendingTile = true
    }

    /// Force calculate snapshot (for testing or manual trigger)
    func calculateSnapshot() async {
        isLoading = true
        defer { isLoading = false }

        // Get previous week's date range (Mon-Sun)
        let (lastMonday, lastSunday) = getPreviousWeekRange()

        // Fetch daily steps for last week
        let dailySteps = await fetchDailySteps(from: lastMonday, to: lastSunday)

        guard !dailySteps.isEmpty else {
            currentSnapshot = nil
            return
        }

        // Calculate the Big 4
        let totalSteps = dailySteps.reduce(0) { $0 + $1.steps }

        // Best day
        let bestDay = dailySteps.max(by: { $0.steps < $1.steps })
        let bestDayName = bestDay.map { dayName(for: $0.date) }
        let bestDaySteps = bestDay?.steps

        // Distance (rough estimate: 2,000 steps ≈ 1 mile)
        let totalMiles = totalSteps / 2000

        // Previous week comparison
        let (prevMonday, prevSunday) = getWeekRange(weeksBefore: 2)
        let prevDailySteps = await fetchDailySteps(from: prevMonday, to: prevSunday)
        let prevTotal = prevDailySteps.reduce(0) { $0 + $1.steps }

        var percentageChange: Int? = nil
        if prevTotal > 0 {
            let change = Double(totalSteps - prevTotal) / Double(prevTotal) * 100
            percentageChange = Int(change)
        }

        currentSnapshot = WeeklySnapshot(
            weekStartDate: lastMonday,
            weekEndDate: lastSunday,
            totalSteps: totalSteps,
            percentageChange: percentageChange,
            bestDayName: bestDayName,
            bestDaySteps: bestDaySteps,
            totalMiles: totalMiles
        )
    }

    /// Mark snapshot as shown (called when user taps "Awesome!" on full modal)
    func markAsShown() {
        UserDefaults.standard.set(Date(), forKey: snapshotShownKey)
        shouldShowSnapshot = false
        // Note: We do NOT clear hasPendingTile here - tile persists until explicitly dismissed
    }

    /// Dismiss the pending tile (user pressed X)
    func dismissPendingTile() {
        hasPendingTile = false
        currentSnapshot = nil
        UserDefaults.standard.removeObject(forKey: pendingSnapshotKey)
        UserDefaults.standard.removeObject(forKey: pendingWeekStartKey)
    }

    // MARK: - Persistence

    /// Load any pending snapshot from UserDefaults
    func loadPendingSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: pendingSnapshotKey),
              let weekStart = UserDefaults.standard.object(forKey: pendingWeekStartKey) as? Date else {
            hasPendingTile = false
            return
        }

        // Check if snapshot is stale (more than 2 weeks old - discard)
        let twoWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
        if weekStart < twoWeeksAgo {
            // Stale snapshot - discard
            dismissPendingTile()
            return
        }

        // Decode and restore
        do {
            let snapshot = try JSONDecoder().decode(WeeklySnapshot.self, from: data)
            currentSnapshot = snapshot
            hasPendingTile = true
        } catch {
            print("❌ Failed to decode pending snapshot: \(error)")
            dismissPendingTile()
        }
    }

    /// Load pending snapshot if it's still valid for the current week
    /// Returns true if a valid pending snapshot was loaded
    @discardableResult
    private func loadPendingSnapshotIfValid() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: pendingSnapshotKey),
              let weekStart = UserDefaults.standard.object(forKey: pendingWeekStartKey) as? Date else {
            return false
        }

        // Check if this snapshot covers the previous week (still relevant)
        let (lastMonday, _) = getPreviousWeekRange()

        // If the stored week matches the previous week, it's still valid
        if calendar.isDate(weekStart, inSameDayAs: lastMonday) {
            do {
                let snapshot = try JSONDecoder().decode(WeeklySnapshot.self, from: data)
                currentSnapshot = snapshot
                return true
            } catch {
                return false
            }
        }

        // Snapshot is for an older week - it will be replaced when new one is calculated
        return false
    }

    /// Save current snapshot to UserDefaults for persistence
    private func savePendingSnapshot() {
        guard let snapshot = currentSnapshot else { return }

        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: pendingSnapshotKey)
            UserDefaults.standard.set(snapshot.weekStartDate, forKey: pendingWeekStartKey)
        } catch {
            print("❌ Failed to encode snapshot for persistence: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func getPreviousWeekRange() -> (Date, Date) {
        getWeekRange(weeksBefore: 1)
    }

    private func getWeekRange(weeksBefore: Int) -> (Date, Date) {
        let today = calendar.startOfDay(for: Date())

        // Find this Monday
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7  // Monday = 2, so (2+5)%7 = 0

        guard let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today),
              let targetMonday = calendar.date(byAdding: .weekOfYear, value: -weeksBefore, to: thisMonday),
              let targetSunday = calendar.date(byAdding: .day, value: 6, to: targetMonday) else {
            return (today, today)
        }

        return (targetMonday, targetSunday)
    }

    private func fetchDailySteps(from startDate: Date, to endDate: Date) async -> [(date: Date, steps: Int)] {
        var results: [(date: Date, steps: Int)] = []

        var currentDate = startDate
        while currentDate <= endDate {
            do {
                let steps = try await HealthKitService.shared.fetchSteps(for: currentDate)
                results.append((date: currentDate, steps: steps))
            } catch {
                results.append((date: currentDate, steps: 0))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return results
    }

    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"  // Full day name
        return formatter.string(from: date)
    }
}
