//
//  CloudKitSyncHandler.swift
//  Just Walk
//
//  Monitors SwiftData + CloudKit sync status and handles merge conflicts.
//  StreakData and DailyStats are automatically synced to iCloud via SwiftData.
//

import Foundation
import SwiftData
import CloudKit
import Combine

/// Monitors CloudKit sync status for SwiftData models.
/// SwiftData handles sync automatically - this provides visibility and conflict resolution.
@MainActor
final class CloudKitSyncHandler: ObservableObject {

    static let shared = CloudKitSyncHandler()

    // MARK: - Published State

    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var errorMessage: String?

    enum SyncStatus: String {
        case idle = "Idle"
        case syncing = "Syncing..."
        case synced = "Synced"
        case error = "Error"
        case noAccount = "No iCloud"
    }

    // MARK: - Private Properties

    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Check iCloud account status on init
        Task {
            await checkAccountStatus()
        }

        // Listen for iCloud account changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Account Status

    private func checkAccountStatus() async {
        do {
            let container = CKContainer(identifier: "iCloud.onworldtech.Just-Walk")
            let status = try await container.accountStatus()

            switch status {
            case .available:
                syncStatus = .synced
                print("☁️ CloudKit: iCloud account available - sync enabled")
            case .noAccount:
                syncStatus = .noAccount
                print("☁️ CloudKit: No iCloud account - local storage only")
            case .restricted:
                syncStatus = .noAccount
                errorMessage = "iCloud access restricted"
            case .couldNotDetermine:
                syncStatus = .idle
                errorMessage = "Could not determine iCloud status"
            case .temporarilyUnavailable:
                syncStatus = .idle
                errorMessage = "iCloud temporarily unavailable"
            @unknown default:
                syncStatus = .idle
            }
        } catch {
            syncStatus = .error
            errorMessage = error.localizedDescription
            print("☁️ CloudKit: Error checking account - \(error.localizedDescription)")
        }
    }

    // MARK: - Streak Conflict Resolution

    /// Resolves conflicts between local and remote StreakData.
    /// Strategy: Take the highest values, union all shielded dates.
    /// Called if SwiftData detects a merge conflict (rare with CloudKit).
    func resolveStreakConflict(local: StreakData, remote: StreakData) {
        // Keep highest streak values (user should never lose progress)
        local.currentStreak = max(local.currentStreak, remote.currentStreak)
        local.longestStreak = max(local.longestStreak, remote.longestStreak)

        // Keep most shields (user paid for these)
        local.shieldsRemaining = max(local.shieldsRemaining, remote.shieldsRemaining)

        // Union shielded dates (don't lose any protected days)
        let allDates = Set(local.shieldedDates).union(Set(remote.shieldedDates))
        local.shieldedDates = Array(allDates).sorted()

        // Keep most recent goal met date
        if let localDate = local.lastGoalMetDate, let remoteDate = remote.lastGoalMetDate {
            local.lastGoalMetDate = max(localDate, remoteDate)
        } else {
            local.lastGoalMetDate = local.lastGoalMetDate ?? remote.lastGoalMetDate
        }

        // Keep earliest streak start date (longer streak)
        if let localDate = local.streakStartDate, let remoteDate = remote.streakStartDate {
            local.streakStartDate = min(localDate, remoteDate)
        } else {
            local.streakStartDate = local.streakStartDate ?? remote.streakStartDate
        }

        // Keep highest total days
        local.totalDaysGoalMet = max(local.totalDaysGoalMet, remote.totalDaysGoalMet)

        // Update timestamp
        local.updatedAt = Date()

        print("☁️ CloudKit: Resolved streak conflict - streak=\(local.currentStreak), shields=\(local.shieldsRemaining)")
    }

    // MARK: - DailyStats Conflict Resolution

    /// Resolves conflicts between local and remote DailyStats.
    /// Strategy: Take the highest step count (most accurate data).
    func resolveDailyStatsConflict(local: DailyStats, remote: DailyStats) {
        // Keep highest step count (most complete data)
        if remote.totalSteps > local.totalSteps {
            local.totalSteps = remote.totalSteps
            local.totalDistance = remote.totalDistance
            local.totalDuration = remote.totalDuration
            local.sessionsCompleted = remote.sessionsCompleted
            local.iwtSessionsCompleted = remote.iwtSessionsCompleted
            local.caloriesBurned = remote.caloriesBurned
        }

        // Goal reached if either device recorded it
        local.goalReached = local.goalReached || remote.goalReached

        // Keep historical goal if either has it
        local.historicalGoal = local.historicalGoal ?? remote.historicalGoal

        print("☁️ CloudKit: Resolved DailyStats conflict for \(local.date.formatted(date: .abbreviated, time: .omitted))")
    }

    // MARK: - Force Sync

    /// Force a sync refresh (SwiftData usually handles this automatically)
    func forceSync() {
        guard syncStatus != .noAccount else {
            print("☁️ CloudKit: Cannot sync - no iCloud account")
            return
        }

        syncStatus = .syncing

        // SwiftData syncs automatically, but we can trigger a context save
        // to push any pending local changes
        do {
            try modelContext?.save()
            lastSyncDate = Date()
            syncStatus = .synced
            print("☁️ CloudKit: Force sync completed")
        } catch {
            syncStatus = .error
            errorMessage = error.localizedDescription
            print("☁️ CloudKit: Force sync failed - \(error)")
        }
    }

    // MARK: - Debug Info

    var debugStatusText: String {
        var text = "Status: \(syncStatus.rawValue)"
        if let lastSync = lastSyncDate {
            text += "\nLast sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))"
        }
        if let error = errorMessage {
            text += "\nError: \(error)"
        }
        return text
    }
}
