//
//  StreakResurrectionManager.swift
//  Just Walk
//
//  Reconciles local DailyStats with HealthKit historical records.
//  Runs silently on app launch and foreground.
//
//  Key Principles:
//  1. Anchor to history: Query from min(appInstallDate, 365_days_ago)
//  2. HealthKit is truth: For historical days, HealthKit > Local always wins
//  3. Protect today: Never overwrite today's optimistic handshake value
//  4. Fail silently: If no HealthKit permission, skip gracefully
//

import Foundation
import SwiftData
import HealthKit

@MainActor
final class StreakResurrectionManager {

    static let shared = StreakResurrectionManager()

    // MARK: - Constants

    private enum Keys {
        static let appInstallDate = "com.justwalk.appInstallDate"
        static let lastResurrectionDate = "com.justwalk.lastResurrectionDate"
    }

    private let maxBackfillDays = 365
    private let throttleInterval: TimeInterval = 6 * 60 * 60  // 6 hours

    // MARK: - State

    private var modelContext: ModelContext?
    private var isRunning = false
    private let calendar = Calendar.current

    // MARK: - Initialization

    private init() {
        ensureAppInstallDateTracked()
    }

    // MARK: - Setup

    /// Inject SwiftData model context (call from app startup)
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        // Run migration for legacy records on context set
        migrateHistoricalGoals(context: context)
    }

    // MARK: - Migration

    /// Backfill existing DailyStats records that have nil historicalGoal.
    /// This is idempotent - only affects records with nil.
    private func migrateHistoricalGoals(context: ModelContext) {
        do {
            // Fetch all records without historicalGoal
            let descriptor = FetchDescriptor<DailyStats>(
                predicate: #Predicate { $0.historicalGoal == nil }
            )
            let legacyRecords = try context.fetch(descriptor)

            guard !legacyRecords.isEmpty else { return }

            // Use current goal, defaulting to 10k only if no goal set (0)
            let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
            let defaultGoal = savedGoal > 0 ? savedGoal : 10_000

            for record in legacyRecords {
                record.historicalGoal = defaultGoal
            }

            try context.save()
            print("📊 StreakResurrection: Migrated \(legacyRecords.count) DailyStats with historicalGoal = \(defaultGoal)")

        } catch {
            print("⚠️ StreakResurrection: Migration failed: \(error)")
        }
    }

    // MARK: - App Install Date

    var appInstallDate: Date? {
        UserDefaults.standard.object(forKey: Keys.appInstallDate) as? Date
    }

    /// Anchor date: Always 365 days ago to capture full pre-install history.
    /// This ensures the "Time Traveler" scenario works - new users get their
    /// entire HealthKit history backfilled, not just data since install.
    var anchorDate: Date {
        calendar.date(byAdding: .day, value: -maxBackfillDays, to: Date())!
    }

    private func ensureAppInstallDateTracked() {
        guard appInstallDate == nil else { return }
        UserDefaults.standard.set(Date(), forKey: Keys.appInstallDate)
        print("📅 StreakResurrection: Install date recorded")
    }

    // MARK: - Public API

    /// Trigger reconciliation (throttled, safe to call frequently)
    func triggerReconciliation() async {
        guard !isRunning else {
            print("⏸️ StreakResurrection: Already running, skipping")
            return
        }

        // Throttle check
        if let lastRun = UserDefaults.standard.object(forKey: Keys.lastResurrectionDate) as? Date,
           Date().timeIntervalSince(lastRun) < throttleInterval {
            print("⏸️ StreakResurrection: Throttled (last run \(Int(Date().timeIntervalSince(lastRun) / 60))m ago)")
            return
        }

        guard let context = modelContext else {
            print("⚠️ StreakResurrection: No model context")
            return
        }

        guard HealthKitService.shared.isHealthKitAuthorized else {
            print("⏸️ StreakResurrection: HealthKit not authorized")
            return
        }

        await performReconciliation(context: context)
    }

    /// Force reconciliation (bypasses throttle - for debug)
    func forceReconciliation() async {
        guard let context = modelContext else {
            print("⚠️ StreakResurrection: No model context")
            return
        }

        guard HealthKitService.shared.isHealthKitAuthorized else {
            print("⚠️ StreakResurrection: HealthKit not authorized")
            return
        }

        await performReconciliation(context: context)
    }

    // MARK: - Core Logic

    private func performReconciliation(context: ModelContext) async {
        isRunning = true
        let startTime = Date()
        print("🔄 StreakResurrection: Starting from \(anchorDate)")

        do {
            // Fetch HealthKit data (uses HKStatisticsCollectionQuery internally)
            let startDate = calendar.startOfDay(for: anchorDate)
            let endDate = calendar.startOfDay(for: Date())
            let healthKitData = try await HealthKitService.shared.fetchDailyStepStatistics(
                from: startDate,
                to: endDate
            )

            var updated = 0, created = 0
            let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
            let stepGoal = savedGoal > 0 ? savedGoal : 10_000
            let today = calendar.startOfDay(for: Date())

            // Reconcile each day
            for dayData in healthKitData {
                let dayStart = calendar.startOfDay(for: dayData.date)
                let isToday = calendar.isDate(dayStart, inSameDayAs: today)

                let result = reconcileDay(
                    date: dayStart,
                    healthKitSteps: dayData.steps,
                    stepGoal: stepGoal,
                    isToday: isToday,
                    context: context
                )

                if result == .updated { updated += 1 }
                if result == .created { created += 1 }
            }

            // Save changes
            try context.save()

            // Recalculate streak from updated history
            StreakService.shared.recalculateStreakFromHistory(context: context)

            // Mark complete
            UserDefaults.standard.set(Date(), forKey: Keys.lastResurrectionDate)

            let duration = Date().timeIntervalSince(startTime)
            print("✅ StreakResurrection: Complete in \(String(format: "%.2f", duration))s")
            print("   - Updated: \(updated) days, Created: \(created) days")
            print("   - Range: \(startDate) to \(endDate)")

        } catch {
            print("❌ StreakResurrection: \(error)")
        }

        isRunning = false
    }

    // MARK: - Day Reconciliation

    private enum ReconcileResult {
        case updated
        case created
        case skipped
    }

    private func reconcileDay(
        date: Date,
        healthKitSteps: Int,
        stepGoal: Int,
        isToday: Bool,
        context: ModelContext
    ) -> ReconcileResult {

        let endOfDay = calendar.date(byAdding: .day, value: 1, to: date)!
        let predicate = #Predicate<DailyStats> { $0.date >= date && $0.date < endOfDay }

        do {
            let results = try context.fetch(FetchDescriptor<DailyStats>(predicate: predicate))

            if let existing = results.first {
                // SAFETY: Never overwrite today with lower value
                // This preserves the optimistic handshake value
                if isToday && healthKitSteps < existing.totalSteps {
                    return .skipped
                }

                // RETROACTIVE GOAL: Always use current goal for all days
                // This allows goal changes to apply to historical data
                let effectiveGoal = stepGoal

                // OVERWRITE RULE: HealthKit > Local
                if healthKitSteps > existing.totalSteps {
                    existing.totalSteps = healthKitSteps
                    existing.goalReached = healthKitSteps >= effectiveGoal
                    existing.historicalGoal = stepGoal  // Always update to current goal

                    return .updated
                }

                return .skipped

            } else if healthKitSteps > 0 {
                // No local record exists - create new with current goal snapshot
                let newStats = DailyStats(
                    date: date,
                    totalSteps: healthKitSteps,
                    goalReached: healthKitSteps >= stepGoal,
                    historicalGoal: stepGoal  // Snapshot current goal for new records
                )
                context.insert(newStats)
                return .created
            }

            return .skipped

        } catch {
            print("⚠️ StreakResurrection: Failed to reconcile \(date): \(error)")
            return .skipped
        }
    }
}
