//
//  StreakService.swift
//  Just Walk
//
//  Manages streak tracking logic and persistence.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class StreakService: ObservableObject {

    static let shared = StreakService()

    // MARK: - Published State

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var totalDaysGoalMet: Int = 0
    @Published private(set) var lastGoalMetDate: Date?
    @Published private(set) var streakStartDate: Date?
    @Published private(set) var isLoaded: Bool = false

    // MARK: - Streak Lost State (for UI "streak ended" state)

    @Published private(set) var streakWasLostToday: Bool = false
    @Published private(set) var previousStreakBeforeLoss: Int = 0

    private let streakLostSeenKey = "streakLostSeenDate"
    private let seenMilestonesKey = "seenStreakMilestones.card"

    // MARK: - Private State

    private var modelContext: ModelContext?

    // MARK: - Initialization

    private init() {
        #if DEBUG
        // Listen for test scenario changes
        NotificationCenter.default.addObserver(
            forName: .testDataScenarioChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadStreakData()
            }
        }
        #endif
    }

    // MARK: - Setup

    /// Inject the model context (call from app startup)
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadStreakData()
    }

    // MARK: - Core Logic

    /// Load streak data from SwiftData
    func loadStreakData() {
        // Use test data when test mode is enabled (DEBUG only)
        #if DEBUG
        if TestDataProvider.shared.isTestDataEnabled {
            currentStreak = TestDataProvider.shared.currentStreak
            longestStreak = max(currentStreak, 14)  // Mock longest streak
            totalDaysGoalMet = currentStreak + 50   // Mock total days
            lastGoalMetDate = currentStreak > 0 ? Date() : nil
            streakStartDate = currentStreak > 0 ? Calendar.current.date(byAdding: .day, value: -currentStreak + 1, to: Date()) : nil
            isLoaded = true
            print("🔥 StreakService: Using test data (streak = \(currentStreak))")
            return
        }
        #endif

        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<StreakData>()

        do {
            let results = try context.fetch(descriptor)
            if let streakData = results.first {
                // Validate streak is still active before loading
                validateAndUpdateStreak(streakData: streakData, context: context)
            } else {
                // First time - create initial record
                let newStreak = StreakData()
                context.insert(newStreak)
                try context.save()
                updatePublishedValues(from: newStreak)
            }

            // Mark as loaded (prevents "0 Day Streak" flash on launch)
            isLoaded = true

            // Check and grant monthly shield for Pro users
            checkAndGrantMonthlyShield()
        } catch {
            print("Failed to load streak data: \(error)")
            isLoaded = true  // Still mark loaded to prevent infinite loading state
        }
    }

    /// Called when daily goal is reached
    /// - Parameters:
    ///   - date: The date the goal was reached (usually today)
    ///   - context: SwiftData context
    func goalReached(for date: Date, context: ModelContext) {
        let calendar = Calendar.current
        let goalDate = calendar.startOfDay(for: date)

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            let streakData: StreakData
            if let existing = results.first {
                streakData = existing
            } else {
                streakData = StreakData()
                context.insert(streakData)
            }

            // Check if we already counted this day
            if let lastDate = streakData.lastGoalMetDate,
               calendar.isDate(lastDate, inSameDayAs: goalDate) {
                // Already recorded for this day
                return
            }

            // Check if streak should continue or start fresh
            if let lastDate = streakData.lastGoalMetDate {
                let lastGoalDay = calendar.startOfDay(for: lastDate)

                // Check if this is consecutive (yesterday or today)
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: goalDate),
                   calendar.isDate(lastGoalDay, inSameDayAs: yesterday) {
                    // Consecutive! Increment streak
                    streakData.currentStreak += 1
                } else if calendar.isDate(lastGoalDay, inSameDayAs: goalDate) {
                    // Same day, already handled above
                    return
                } else {
                    // Gap detected - start new streak
                    streakData.currentStreak = 1
                    streakData.streakStartDate = goalDate
                }
            } else {
                // First time ever
                streakData.currentStreak = 1
                streakData.streakStartDate = goalDate
            }

            // Update records
            streakData.lastGoalMetDate = goalDate
            streakData.totalDaysGoalMet += 1
            streakData.updatedAt = Date()

            // Check for new record
            if streakData.currentStreak > streakData.longestStreak {
                streakData.longestStreak = streakData.currentStreak
            }

            try context.save()
            updatePublishedValues(from: streakData)

            // Trigger milestone notification if applicable
            NotificationManager.shared.scheduleStreakMilestoneNotification(newStreak: streakData.currentStreak)

            // Cancel streak-at-risk notification since goal was reached
            NotificationManager.shared.cancelStreakAtRiskNotification()

            print("🔥 Streak updated: \(streakData.currentStreak) days")

        } catch {
            print("Failed to update streak: \(error)")
        }
    }

    /// Validate streak on app open (check if it should be reset)
    func validateStreakOnAppOpen(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            guard let streakData = results.first else { return }

            validateAndUpdateStreak(streakData: streakData, context: context)
        } catch {
            print("Failed to validate streak: \(error)")
        }
    }

    // MARK: - Failsafe Validation Before Breaking

    /// Performs a "Hail Mary" HealthKit check before breaking a streak.
    /// Returns true if streak should be KEPT (HealthKit found missing data).
    /// Returns false if streak should be BROKEN (HealthKit confirms gap).
    private func validateStreakBeforeBreaking(
        missedDate: Date,
        context: ModelContext
    ) async -> Bool {
        let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        let stepGoal = savedGoal > 0 ? savedGoal : 10_000

        print("🛡️ StreakGuard: Performing Hail Mary check for \(missedDate.formatted(date: .abbreviated, time: .omitted))")

        do {
            // Fresh fetch from HealthKit (bypasses any cache)
            let healthKitSteps = try await HealthKitService.shared.fetchStepsFresh(for: missedDate)

            print("🛡️ StreakGuard: HealthKit returned \(healthKitSteps) steps for missed day")

            if healthKitSteps >= stepGoal {
                // SAVE THE STREAK! HealthKit had the data all along
                print("🛡️ StreakGuard: SAVED! Repairing local data...")

                // Silently repair DailyStats
                await repairDailyStats(
                    date: missedDate,
                    steps: healthKitSteps,
                    stepGoal: stepGoal,
                    context: context
                )

                return true  // Abort the break
            } else {
                print("🛡️ StreakGuard: Confirmed - goal not met (\(healthKitSteps)/\(stepGoal))")
                return false  // Proceed with break
            }

        } catch {
            print("🛡️ StreakGuard: HealthKit fetch failed - \(error)")
            // On error, be conservative and allow the break
            return false
        }
    }

    /// Repair DailyStats for a missed day that HealthKit confirmed was actually completed
    private func repairDailyStats(
        date: Date,
        steps: Int,
        stepGoal: Int,
        context: ModelContext
    ) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let predicate = #Predicate<DailyStats> {
                $0.date >= startOfDay && $0.date < endOfDay
            }
            let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
            let results = try context.fetch(descriptor)

            if let existing = results.first {
                existing.totalSteps = max(existing.totalSteps, steps)
                existing.goalReached = true
            } else {
                let newStats = DailyStats(
                    date: startOfDay,
                    totalSteps: steps,
                    goalReached: true
                )
                context.insert(newStats)
            }

            try context.save()
            print("🛡️ StreakGuard: Repaired DailyStats for \(startOfDay)")

        } catch {
            print("🛡️ StreakGuard: Failed to repair DailyStats - \(error)")
        }
    }

    // MARK: - Private Helpers

    private func validateAndUpdateStreak(streakData: StreakData, context: ModelContext) {
        guard let lastDate = streakData.lastGoalMetDate else {
            // No lastGoalMetDate - recalculate from actual DailyStats history
            recalculateStreakFromDailyStats(context: context)
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastGoalDay = calendar.startOfDay(for: lastDate)

        // Calculate days since last goal
        let daysSinceGoal = calendar.dateComponents([.day], from: lastGoalDay, to: today).day ?? 0

        if daysSinceGoal > 1 {
            // FAILSAFE: Before breaking, check HealthKit for the missed day
            // The Watch might have synced data while the app was closed
            let missedDay = calendar.date(byAdding: .day, value: 1, to: lastGoalDay)!

            // Capture values before async work to avoid Swift 6 concurrency warning
            let previousStreak = streakData.currentStreak
            let capturedDaysSinceGoal = daysSinceGoal

            Task { @MainActor [weak self] in
                guard let self else { return }
                let shouldKeepStreak = await self.validateStreakBeforeBreaking(
                    missedDate: missedDay,
                    context: context
                )

                if shouldKeepStreak {
                    // Streak saved! Update the goal date and recalculate
                    self.goalReached(for: missedDay, context: context)
                    print("🛡️ StreakGuard: Streak preserved!")
                } else {
                    // Confirmed break - proceed with reset
                    print("🔥 Streak broken - \(capturedDaysSinceGoal) days since last goal")

                    // Reset streak via fresh fetch to avoid capturing mutable streakData
                    self.resetStreak(previousStreak: previousStreak, context: context)
                }
            }
            return  // Exit early - async task handles the rest
        }

        // Recalculate from actual DailyStats history (handles cases where goalReached wasn't called)
        recalculateStreakFromDailyStats(context: context)
    }

    private func updatePublishedValues(from streakData: StreakData) {
        currentStreak = streakData.currentStreak
        longestStreak = streakData.longestStreak
        totalDaysGoalMet = streakData.totalDaysGoalMet
        lastGoalMetDate = streakData.lastGoalMetDate
        streakStartDate = streakData.streakStartDate
    }

    /// Reset streak to zero - fetches fresh StreakData to avoid capturing mutable references
    private func resetStreak(previousStreak: Int, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            guard let streakData = results.first else { return }

            streakData.currentStreak = 0
            streakData.streakStartDate = nil
            streakData.updatedAt = Date()

            try context.save()

            updatePublishedValues(from: streakData)

            // Schedule "streak lost" notification for morning encouragement
            NotificationManager.shared.scheduleStreakLostNotification(previousStreak: previousStreak)

            // Mark streak as lost for UI state (shows "streak ended" card)
            markStreakLost(previousStreak: previousStreak)
        } catch {
            print("Failed to reset streak: \(error)")
        }
    }

    // MARK: - Query Helpers

    /// Get historical goal completion for calendar display (using dynamic comparison)
    /// - Parameters:
    ///   - days: Number of days to look back
    ///   - context: SwiftData context
    /// - Returns: Array of dates where goal was met
    func getGoalMetDates(forPastDays days: Int, context: ModelContext) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else {
            return []
        }

        // Get current goal for dynamic comparison
        let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        let currentGoal = savedGoal > 0 ? savedGoal : 10_000

        do {
            let predicate = #Predicate<DailyStats> {
                $0.date >= startDate
            }
            let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
            let results = try context.fetch(descriptor)

            // Filter dynamically and return dates
            return results
                .filter { $0.totalSteps >= currentGoal }
                .map { calendar.startOfDay(for: $0.date) }
        } catch {
            print("Failed to fetch goal met dates: \(error)")
            return []
        }
    }

    /// Calculate streak from DailyStats (alternative method for verification)
    func calculateStreakFromHistory(context: ModelContext) -> Int {
        let calendar = Calendar.current
        var checkDate = calendar.startOfDay(for: Date())
        var streak = 0

        // First check if today's goal is met
        let todayMet = isDayGoalMet(date: checkDate, context: context)

        // If today's goal isn't met yet, start checking from yesterday
        if !todayMet {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        // Count consecutive days going backward
        while true {
            if isDayGoalMet(date: checkDate, context: context) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    private func isDayGoalMet(date: Date, context: ModelContext) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // First check if date is shielded - shielded days count as goal met
        if isDateShielded(startOfDay) {
            return true
        }

        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return false
        }

        // Get current goal for dynamic comparison (same logic as Activity chart)
        let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        let currentGoal = savedGoal > 0 ? savedGoal : 10_000

        do {
            let predicate = #Predicate<DailyStats> {
                $0.date >= startOfDay && $0.date < endOfDay
            }
            let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
            let results = try context.fetch(descriptor)

            // Dynamic comparison: totalSteps >= currentGoal
            if let stats = results.first {
                return stats.totalSteps >= currentGoal
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Regular Walking Goal Check

    /// Check if daily step goal was reached via regular walking (not IWT)
    /// Called from app foreground handler to update streak from HealthKit steps
    /// - Parameters:
    ///   - currentSteps: Today's step count from HealthKit
    ///   - stepGoal: User's daily step goal
    ///   - context: SwiftData context
    func checkDailyGoalFromSteps(currentSteps: Int, stepGoal: Int, context: ModelContext) {
        guard currentSteps >= stepGoal else { return }

        // Goal is reached - update streak for today
        goalReached(for: Date(), context: context)
    }

    // MARK: - Historical Backfill from HealthKit

    /// Backfill streak data from HealthKit historical step data.
    /// This syncs the past 60 days of HealthKit data with DailyStats and recalculates the streak.
    /// Should be called once on app launch or when streak appears incorrect.
    @Published private(set) var isBackfilling: Bool = false
    @Published private(set) var lastBackfillDate: Date?

    private let backfillKey = "lastStreakBackfillDate"

    /// Check if backfill is needed (hasn't been done today)
    func needsBackfill() -> Bool {
        guard let lastBackfill = UserDefaults.standard.object(forKey: backfillKey) as? Date else {
            return true // Never backfilled
        }
        // Re-backfill if last backfill was more than 12 hours ago
        return Date().timeIntervalSince(lastBackfill) > 12 * 60 * 60
    }

    /// Backfill streak data from HealthKit for the past 60 days
    func backfillFromHealthKit() async {
        guard let context = modelContext else {
            print("⚠️ StreakService: No model context for backfill")
            return
        }

        guard !isBackfilling else {
            print("⚠️ StreakService: Backfill already in progress")
            return
        }

        await MainActor.run {
            isBackfilling = true
        }

        print("🔄 StreakService: Starting HealthKit backfill...")

        let calendar = Calendar.current
        let daysToBackfill = 60

        // Get user's step goal
        let stepGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        let effectiveGoal = stepGoal > 0 ? stepGoal : 10000

        // Fetch historical step data from HealthKit
        do {
            let dailySteps = try await HealthKitService.shared.fetchDailySteps(forPastDays: daysToBackfill)

            var daysMarked = 0

            // Process each day (dailySteps is ordered oldest to newest)
            for dayData in dailySteps {
                let dayStart = calendar.startOfDay(for: dayData.date)

                if dayData.steps >= effectiveGoal {
                    // Mark this day as goal reached
                    await markDayAsGoalReached(date: dayStart, steps: dayData.steps, context: context)
                    daysMarked += 1
                }
            }

            // After backfill, recalculate streak from DailyStats
            await MainActor.run {
                recalculateStreakFromDailyStats(context: context)
            }

            // Mark backfill as complete
            UserDefaults.standard.set(Date(), forKey: backfillKey)

            await MainActor.run {
                isBackfilling = false
                lastBackfillDate = Date()
            }

            print("✅ StreakService: Backfill complete - marked \(daysMarked) days as goal reached")

        } catch {
            print("❌ StreakService: Backfill failed - \(error)")
            await MainActor.run {
                isBackfilling = false
            }
        }
    }

    /// Mark a specific day as goal reached (used during backfill)
    private func markDayAsGoalReached(date: Date, steps: Int, context: ModelContext) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        await MainActor.run {
            do {
                // Check if DailyStats already exists for this day
                let predicate = #Predicate<DailyStats> {
                    $0.date >= startOfDay && $0.date < endOfDay
                }
                let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
                let results = try context.fetch(descriptor)

                if let existingStats = results.first {
                    // Update existing record
                    if !existingStats.goalReached {
                        existingStats.goalReached = true
                        existingStats.totalSteps = max(existingStats.totalSteps, steps)
                    }
                } else {
                    // Create new DailyStats record
                    let newStats = DailyStats(date: startOfDay, totalSteps: steps, goalReached: true)
                    context.insert(newStats)
                }

                try context.save()
            } catch {
                print("⚠️ StreakService: Failed to mark day \(startOfDay) as goal reached: \(error)")
            }
        }
    }

    /// Recalculate streak from DailyStats records (after backfill or goal change)
    func recalculateStreakFromDailyStats(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Count consecutive days going backward from today/yesterday
        var checkDate = today
        var streak = 0
        var totalDays = 0
        var streakStartDate: Date?
        var lastGoalDate: Date?

        // First check if today's goal is met
        let todayMet = isDayGoalMet(date: checkDate, context: context)

        // If today's goal isn't met yet, start checking from yesterday
        if !todayMet {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return
            }
            checkDate = yesterday
        }

        // Count consecutive days
        while true {
            if isDayGoalMet(date: checkDate, context: context) {
                streak += 1
                if lastGoalDate == nil {
                    lastGoalDate = checkDate
                }
                streakStartDate = checkDate

                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                break
            }
        }

        // Count total days goal met (past 365 days)
        if let yearAgo = calendar.date(byAdding: .day, value: -365, to: today) {
            totalDays = countDaysGoalMet(from: yearAgo, to: today, context: context)
        }

        // Update StreakData
        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            let streakData: StreakData
            if let existing = results.first {
                streakData = existing
            } else {
                streakData = StreakData()
                context.insert(streakData)
            }

            streakData.currentStreak = streak
            streakData.totalDaysGoalMet = totalDays
            streakData.lastGoalMetDate = lastGoalDate
            streakData.streakStartDate = streakStartDate
            streakData.updatedAt = Date()

            // Update longest streak if current is higher
            if streak > streakData.longestStreak {
                streakData.longestStreak = streak
            }

            try context.save()
            updatePublishedValues(from: streakData)

            print("🔥 StreakService: Recalculated streak = \(streak) days, total goal days = \(totalDays)")

        } catch {
            print("❌ StreakService: Failed to update streak data: \(error)")
        }
    }

    /// Count how many days the goal was met in a date range (using dynamic comparison)
    private func countDaysGoalMet(from startDate: Date, to endDate: Date, context: ModelContext) -> Int {
        // Get current goal for dynamic comparison
        let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        let currentGoal = savedGoal > 0 ? savedGoal : 10_000

        do {
            let predicate = #Predicate<DailyStats> {
                $0.date >= startDate && $0.date <= endDate
            }
            let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
            let results = try context.fetch(descriptor)
            // Filter dynamically: totalSteps >= currentGoal
            return results.filter { $0.totalSteps >= currentGoal }.count
        } catch {
            return 0
        }
    }

    // MARK: - Public Entry Point for Resurrection Manager

    /// Recalculate streak from DailyStats history.
    /// Called by StreakResurrectionManager after reconciling historical data.
    func recalculateStreakFromHistory(context: ModelContext) {
        recalculateStreakFromDailyStats(context: context)
    }

    // MARK: - Streak Shield (Premium Feature)

    /// Check if a date has been shielded
    func isDateShielded(_ date: Date) -> Bool {
        guard let context = modelContext else { return false }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)
            return results.first?.isDateShielded(date) ?? false
        } catch {
            return false
        }
    }

    /// Get the current StreakData for UI access
    func getStreakData() -> StreakData? {
        guard let context = modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            return nil
        }
    }

    /// Apply a streak shield to a specific date
    /// Anyone with shields can use them (Pro gets free monthly, others purchase)
    /// - Parameter date: The date to shield (pardon a missed day)
    /// - Returns: true if shield was applied successfully
    func applyStreakShield(for date: Date) -> Bool {
        // Note: Pro check removed - anyone with shields can use them
        // Pro users get free monthly shields, non-Pro must purchase

        guard let context = modelContext else {
            print("⚠️ Streak Shield: No model context")
            return false
        }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            guard let streakData = results.first else {
                print("⚠️ Streak Shield: No streak data found")
                return false
            }

            guard streakData.canUseShield else {
                print("⚠️ Streak Shield: No shields remaining")
                return false
            }

            let calendar = Calendar.current

            // Add date to shielded dates
            streakData.shieldedDates.append(calendar.startOfDay(for: date))

            // Use one shield (decrement count)
            _ = streakData.useShield()

            try context.save()

            // Recalculate streak considering shielded dates
            recalculateStreakFromDailyStats(context: context)

            print("🛡️ Streak Shield applied for \(date.formatted(date: .abbreviated, time: .omitted)). Shields remaining: \(streakData.shieldsRemaining)")
            return true

        } catch {
            print("❌ Streak Shield failed: \(error)")
            return false
        }
    }

    // MARK: - Paid Streak Repair

    /// Attempt to repair a broken streak by shielding the break date.
    /// Returns the repaired date on success, nil on failure.
    /// Used by the StoreKit 2 transaction listener - must be atomic.
    func attemptStreakRepair(context: ModelContext) -> Date? {
        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            guard let streakData = results.first else {
                print("❌ StreakRepair: No streak data found")
                return nil
            }

            guard let lastGoalDate = streakData.lastGoalMetDate else {
                print("❌ StreakRepair: No lastGoalMetDate - nothing to repair")
                return nil
            }

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let lastGoalDay = calendar.startOfDay(for: lastGoalDate)

            // Calculate days since last goal
            let daysSinceGoal = calendar.dateComponents([.day], from: lastGoalDay, to: today).day ?? 0

            guard daysSinceGoal > 1 else {
                print("❌ StreakRepair: Streak not broken (daysSinceGoal = \(daysSinceGoal))")
                return nil
            }

            // The break date is the day AFTER lastGoalMetDate
            guard let breakDate = calendar.date(byAdding: .day, value: 1, to: lastGoalDay) else {
                print("❌ StreakRepair: Could not calculate break date")
                return nil
            }

            // Check if already shielded
            if streakData.isDateShielded(breakDate) {
                print("⚠️ StreakRepair: Break date already shielded")
                return breakDate  // Still success - date is protected
            }

            // Apply the shield (pardon) to the break date
            streakData.shieldedDates.append(breakDate)
            streakData.updatedAt = Date()

            try context.save()

            // Recalculate streak with the new shielded date
            recalculateStreakFromDailyStats(context: context)

            print("✅ StreakRepair: Repaired streak by shielding \(breakDate.formatted(date: .abbreviated, time: .omitted))")
            return breakDate

        } catch {
            print("❌ StreakRepair: Failed - \(error)")
            return nil
        }
    }

    /// DEPRECATED: Check and grant monthly shield for Pro users (1 shield)
    /// Use checkAndGrantProMonthlyShields() instead for 3 shields
    func checkAndGrantMonthlyShield() {
        guard FreeTierManager.shared.isPro else { return }
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            guard let streakData = results.first else { return }

            if streakData.shouldGrantMonthlyShield {
                streakData.grantMonthlyShield()
                try context.save()
                print("🛡️ Monthly Streak Shield granted! Total shields: \(streakData.shieldsRemaining)")
            }
        } catch {
            print("❌ Failed to check/grant monthly shield: \(error)")
        }
    }

    /// Check and grant 3 Pro monthly shields (new system)
    /// Call this on app launch, Pro subscription start, or billing refresh
    func checkAndGrantProMonthlyShields() {
        guard FreeTierManager.shared.isPro else { return }
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            guard let streakData = results.first else { return }

            // Migrate old shields first
            streakData.migrateShieldInventory()

            if streakData.shouldRefreshProShields {
                streakData.grantProMonthlyShields()
                try context.save()
                print("🛡️ Pro Monthly Shields granted! 3 shields. Total: \(streakData.totalShieldsRemaining)")
                objectWillChange.send()
            }
        } catch {
            print("❌ Failed to check/grant Pro monthly shields: \(error)")
        }
    }

    /// Use one shield - consumes purchased first, then Pro monthly
    /// Returns true if successful
    func useShield() -> Bool {
        guard let context = modelContext else {
            print("⚠️ Shield Use: No model context")
            return false
        }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            guard let streakData = results.first else { return false }

            let success = streakData.useShield()
            if success {
                try context.save()
                print("🛡️ Shield used. Remaining: Pro=\(streakData.proMonthlyShieldsRemaining), Purchased=\(streakData.purchasedShieldsRemaining)")
                objectWillChange.send()
            }
            return success
        } catch {
            print("❌ Failed to use shield: \(error)")
            return false
        }
    }

    /// Add purchased shields to user's balance (does not require Pro)
    /// Called after successful in-app purchase
    /// - Parameter count: Number of shields to add
    func addPurchasedShields(_ count: Int) {
        guard let context = modelContext else {
            print("⚠️ Shield Purchase: No model context")
            return
        }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            if let streakData = results.first {
                // Migrate old shields first
                streakData.migrateShieldInventory()

                // Add to purchased shields (never expire)
                streakData.addPurchasedShields(count)
                try context.save()
                print("🛡️ Purchased shields added: +\(count). Total: \(streakData.totalShieldsRemaining)")

                // Notify observers
                objectWillChange.send()
            } else {
                // Create new streak data with purchased shields
                let newStreak = StreakData()
                newStreak.purchasedShieldsRemaining = count
                context.insert(newStreak)
                try context.save()
                print("🛡️ Created streak data with \(count) purchased shields")

                objectWillChange.send()
            }
        } catch {
            print("❌ Failed to add purchased shields: \(error)")
        }
    }

    // MARK: - Notifications

    /// Check if streak is at risk (under goal with time remaining today)
    func isStreakAtRisk(currentSteps: Int, stepGoal: Int) -> Bool {
        // Only at risk if we have an active streak and haven't met goal yet
        guard currentStreak > 0 else { return false }
        return currentSteps < stepGoal
    }

    /// Get steps remaining to maintain streak
    func stepsToMaintainStreak(currentSteps: Int, stepGoal: Int) -> Int {
        return max(0, stepGoal - currentSteps)
    }

    // MARK: - Debug Methods

    /// Debug: Mark a specific date as goal reached using the stored model context
    /// Called from SettingsViewModel debug functions
    func debugMarkGoalReached(for date: Date) {
        guard let context = modelContext else {
            print("⚠️ Debug: No model context available for streak update")
            return
        }

        // 1. Update StreakData
        goalReached(for: date, context: context)

        // 2. Also update DailyStats.goalReached so calendar shows checkmark
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let predicate = #Predicate<DailyStats> {
                $0.date >= startOfDay && $0.date < endOfDay
            }
            let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
            let results = try context.fetch(descriptor)

            if let stats = results.first {
                stats.goalReached = true
                try context.save()
            } else {
                // Create new DailyStats record if none exists
                let newStats = DailyStats(date: startOfDay, totalSteps: 12000, goalReached: true)
                context.insert(newStats)
                try context.save()
            }
        } catch {
            print("⚠️ Debug: Failed to update DailyStats: \(error)")
        }

        print("🔧 Debug: Marked \(date.formatted(date: .abbreviated, time: .omitted)) as goal reached (StreakData + DailyStats)")
    }

    #if DEBUG
    /// Debug: Manually set a streak by marking consecutive days as goal reached
    /// Call this after using debug tools to set step counts for past days
    /// - Parameters:
    ///   - days: Number of consecutive days to mark (including today)
    ///   - context: SwiftData context
    func debugSetStreak(days: Int, context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Mark each day starting from the oldest and working forward
        for i in (0..<days).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                goalReached(for: date, context: context)
            }
        }

        print("🔧 Debug: Set streak to \(days) days")
    }

    /// Debug: Reset streak to zero
    func debugResetStreak(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            if let streakData = results.first {
                streakData.currentStreak = 0
                streakData.lastGoalMetDate = nil
                streakData.streakStartDate = nil
                streakData.updatedAt = Date()
                try context.save()
                updatePublishedValues(from: streakData)
                print("🔧 Debug: Streak reset to 0")
            }
        } catch {
            print("Debug reset failed: \(error)")
        }
    }
    #endif

    /// Debug: Grant 1 streak shield for testing
    func grantDebugShield() {
        guard let context = modelContext else {
            print("⚠️ Debug: No model context for shield grant")
            return
        }

        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            if let streakData = results.first {
                streakData.shieldsRemaining += 1
                streakData.updatedAt = Date()
                try context.save()
                print("🛡️ Debug: Granted 1 streak shield. Total shields: \(streakData.shieldsRemaining)")
            } else {
                // Create new streak data with 1 shield
                let newStreak = StreakData()
                newStreak.shieldsRemaining = 1
                context.insert(newStreak)
                try context.save()
                print("🛡️ Debug: Created streak data and granted 1 shield")
            }
        } catch {
            print("❌ Debug: Failed to grant shield: \(error)")
        }
    }

    /// Debug: Set up a scenario with a shieldable missed day
    /// Creates: active streak, 1 shield, and a missed day 2 days ago that can be shielded
    func debugSetupShieldableDay() {
        guard let context = modelContext else {
            print("⚠️ Debug: No model context")
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        do {
            // 1. Get or create StreakData
            let descriptor = FetchDescriptor<StreakData>()
            let results = try context.fetch(descriptor)

            let streakData: StreakData
            if let existing = results.first {
                streakData = existing
            } else {
                streakData = StreakData()
                context.insert(streakData)
            }

            // 2. Grant a shield if none available
            if streakData.shieldsRemaining == 0 {
                streakData.shieldsRemaining = 1
            }

            // 3. Set up an active streak (5 days)
            // Mark today as goal reached
            streakData.currentStreak = 5
            streakData.lastGoalMetDate = today
            streakData.streakStartDate = calendar.date(byAdding: .day, value: -4, to: today)
            streakData.longestStreak = max(streakData.longestStreak, 5)
            streakData.updatedAt = Date()

            try context.save()

            // 4. Create DailyStats for the past 5 days
            // Days -4, -3, -1, 0 (today) = goal reached
            // Day -2 = missed (shieldable)
            let goalDays = [-4, -3, -1, 0]  // These days met the goal
            let missedDay = -2  // This day missed (will be shieldable)

            for dayOffset in goalDays {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                    createOrUpdateDailyStats(date: date, steps: 12000, goalReached: true, context: context)
                }
            }

            // Create missed day with low steps
            if let missedDate = calendar.date(byAdding: .day, value: missedDay, to: today) {
                createOrUpdateDailyStats(date: missedDate, steps: 2500, goalReached: false, context: context)
            }

            try context.save()
            updatePublishedValues(from: streakData)
            objectWillChange.send()

            print("🔧 Debug: Set up shieldable day scenario")
            print("   - Active streak: 5 days")
            print("   - Shields: \(streakData.shieldsRemaining)")
            print("   - Missed day 2 days ago (shieldable)")

        } catch {
            print("❌ Debug: Failed to set up shieldable day: \(error)")
        }
    }

    /// Helper to create or update DailyStats
    private func createOrUpdateDailyStats(date: Date, steps: Int, goalReached: Bool, context: ModelContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            let predicate = #Predicate<DailyStats> {
                $0.date >= startOfDay && $0.date < endOfDay
            }
            let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
            let results = try context.fetch(descriptor)

            if let existing = results.first {
                existing.totalSteps = steps
                existing.goalReached = goalReached
            } else {
                let newStats = DailyStats(date: startOfDay, totalSteps: steps, goalReached: goalReached)
                context.insert(newStats)
            }
        } catch {
            print("⚠️ Debug: Failed to create/update DailyStats: \(error)")
        }
    }

    // MARK: - Streak Card State Support

    /// Mark that streak was lost today (for UI "Streak Ended" state)
    func markStreakLost(previousStreak: Int) {
        previousStreakBeforeLoss = previousStreak
        streakWasLostToday = true
    }

    /// Mark that user has seen the "streak lost" state (dismisses it)
    func markStreakLostSeen() {
        streakWasLostToday = false
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: streakLostSeenKey)
    }

    // MARK: - Milestone Tracking (for Streak Card)

    /// Check if current streak is at a milestone that hasn't been seen yet
    var isAtMilestone: Bool {
        guard currentStreak > 0 else { return false }
        return StreakMilestone.allValues.contains(currentStreak) && !hasSeenMilestone(currentStreak)
    }

    /// Check if a specific milestone has been seen/celebrated
    func hasSeenMilestone(_ days: Int) -> Bool {
        let seen = UserDefaults.standard.array(forKey: seenMilestonesKey) as? [Int] ?? []
        return seen.contains(days)
    }

    /// Mark a milestone as seen (after celebration/share)
    func markMilestoneSeen(_ days: Int) {
        var seen = UserDefaults.standard.array(forKey: seenMilestonesKey) as? [Int] ?? []
        if !seen.contains(days) {
            seen.append(days)
            UserDefaults.standard.set(seen, forKey: seenMilestonesKey)
        }
    }

    // MARK: - Today Shield Check (for Streak Card "Protected" state)

    /// Check if today is protected by a streak shield
    var isTodayShielded: Bool {
        guard let streakData = getStreakData() else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        return streakData.shieldedDates.contains {
            Calendar.current.isDate($0, inSameDayAs: today)
        }
    }
}
