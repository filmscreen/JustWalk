//
//  CloudKitSyncManager.swift
//  JustWalk
//
//  CloudKit sync for game state, daily logs, and tracked walks
//

import Foundation
import CloudKit
import os.log

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case error(String)

    var displayText: String {
        switch self {
        case .idle: return "Idle"
        case .syncing: return "Syncing..."
        case .success: return "Success"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - CloudKitSyncManager

@Observable
class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()

    // State
    var syncStatus: SyncStatus = .idle
    var lastSyncDate: Date?

    // CloudKit setup
    private let container: CKContainer
    private let privateDB: CKDatabase
    private let zoneID: CKRecordZone.ID

    // Record type constants
    private enum RecordType {
        static let userGameState = "UserGameState"
        static let dailyLog = "DailyLog"
        static let trackedWalk = "TrackedWalk"
    }

    // Fixed record IDs for single-instance records
    private let gameStateRecordName = "UserGameState_v1"

    // Debounce
    private var pushWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 2.0

    // Prevent re-entrant syncs
    private var isSyncing = false

    // Flag to suppress push notifications triggered by our own merges
    private var isMerging = false

    // Retry state
    private var retryCount = 0
    private let maxRetries = 3
    private var pendingRetry = false

    private let logger = Logger(subsystem: "onworldtech.JustWalk", category: "CloudKitSync")

    private init() {
        container = CKContainer(identifier: "iCloud.onworldtech.JustWalk")
        privateDB = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "JustWalkZone", ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Setup

    func setup() {
        createZoneIfNeeded()
        observePersistenceNotifications()
        pullFromCloud()
    }

    private func createZoneIfNeeded() {
        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone])
        operation.modifyRecordZonesResultBlock = { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("CloudKit zone ready")
            case .failure(let error):
                self?.logger.error("Failed to create zone: \(error.localizedDescription)")
            }
        }
        privateDB.add(operation)
    }

    private func observePersistenceNotifications() {
        let names: [Notification.Name] = [
            .didSaveStreakData,
            .didSaveShieldData,
            .didSaveDailyLog,
            .didSaveTrackedWalk,
            .didSaveProfile
        ]
        for name in names {
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, !self.isMerging else { return }
                self.schedulePush()
            }
        }
    }

    // MARK: - Debounced Push

    func schedulePush() {
        pushWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.pushAllToCloud()
        }
        pushWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    // MARK: - Force Sync (push + pull)

    func forceSync() {
        pushAllToCloud()
        // Pull after a brief delay to let the push settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.pullFromCloud()
        }
    }

    // MARK: - Push All To Cloud

    func pushAllToCloud() {
        // Cancel any pending debounced push to avoid double-push
        pushWorkItem?.cancel()

        guard !isSyncing else { return }
        isSyncing = true

        Task { @MainActor in
            syncStatus = .syncing
        }

        let persistence = PersistenceManager.shared

        // Build game state record
        let gameStateRecord = buildGameStateRecord(persistence: persistence)

        // Build daily log records (ALL logs — no cutoff)
        let dailyLogs = persistence.loadAllDailyLogs()
        let logRecords = dailyLogs.map { buildDailyLogRecord($0) }

        // Build tracked walk records (ALL walks — no cutoff)
        let walks = persistence.loadAllTrackedWalks()
        let walkRecords = walks.map { buildTrackedWalkRecord($0) }

        // Combine all records
        let allRecords = [gameStateRecord] + logRecords + walkRecords

        // Batch in groups of 400 (CloudKit limit)
        let batchSize = 400
        let batches = stride(from: 0, to: allRecords.count, by: batchSize).map {
            Array(allRecords[$0..<min($0 + batchSize, allRecords.count)])
        }

        let group = DispatchGroup()
        var pushError: Error?

        for batch in batches {
            group.enter()
            let operation = CKModifyRecordsOperation(recordsToSave: batch)
            operation.savePolicy = .changedKeys
            operation.isAtomic = false
            operation.modifyRecordsResultBlock = { [weak self] result in
                switch result {
                case .success:
                    self?.logger.info("Pushed batch of \(batch.count) records")
                case .failure(let error):
                    self?.logger.error("Push failed: \(error.localizedDescription)")
                    pushError = error
                }
                group.leave()
            }
            privateDB.add(operation)
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isSyncing = false
            if let error = pushError {
                self.syncStatus = .error(error.localizedDescription)
                self.scheduleRetry()
            } else {
                self.syncStatus = .success
                self.lastSyncDate = Date()
                self.retryCount = 0
                self.pendingRetry = false
            }
        }
    }

    // MARK: - Pull From Cloud

    func pullFromCloud() {
        guard !isSyncing else { return }
        isSyncing = true

        Task { @MainActor in
            syncStatus = .syncing
        }

        let group = DispatchGroup()
        var pullError: Error?

        // 1. Fetch game state
        group.enter()
        let gameStateRecordID = CKRecord.ID(recordName: gameStateRecordName, zoneID: zoneID)
        privateDB.fetch(withRecordID: gameStateRecordID) { [weak self] record, error in
            if let record {
                self?.mergeGameState(remote: record)
            } else if let error {
                let ckError = error as? CKError
                // .unknownItem means record doesn't exist yet — not a real error
                if ckError?.code != .unknownItem {
                    self?.logger.error("Pull game state failed: \(error.localizedDescription)")
                    pullError = error
                }
            }
            group.leave()
        }

        // 2. Fetch all daily logs
        group.enter()
        fetchAllRecords(ofType: RecordType.dailyLog) { [weak self] records, error in
            if let records {
                for record in records {
                    self?.mergeDailyLog(remote: record)
                }
            } else if let error {
                self?.logger.error("Pull daily logs failed: \(error.localizedDescription)")
                pullError = error
            }
            group.leave()
        }

        // 3. Fetch all tracked walks
        group.enter()
        fetchAllRecords(ofType: RecordType.trackedWalk) { [weak self] records, error in
            if let records {
                for record in records {
                    self?.mergeTrackedWalk(remote: record)
                }
            } else if let error {
                self?.logger.error("Pull tracked walks failed: \(error.localizedDescription)")
                pullError = error
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isSyncing = false
            if let error = pullError {
                self.syncStatus = .error(error.localizedDescription)
                self.scheduleRetry()
            } else {
                self.syncStatus = .success
                self.lastSyncDate = Date()
                self.retryCount = 0
                self.pendingRetry = false
            }
            // Reload managers after merge
            self.reloadManagers()
        }
    }

    // MARK: - Retry Logic

    private func scheduleRetry() {
        guard retryCount < maxRetries, !pendingRetry else { return }
        pendingRetry = true
        retryCount += 1

        // Exponential backoff: 5s, 15s, 45s
        let delay = TimeInterval(5 * pow(3.0, Double(retryCount - 1)))
        logger.info("Scheduling sync retry #\(self.retryCount) in \(delay)s")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.pendingRetry = false
            self.forceSync()
        }
    }

    // MARK: - Delete Cloud Data (Debug)

    func deleteCloudData() {
        Task { @MainActor in
            syncStatus = .syncing
        }

        let operation = CKModifyRecordZonesOperation(recordZoneIDsToDelete: [zoneID])
        operation.modifyRecordZonesResultBlock = { [weak self] (result: Result<Void, Error>) in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.logger.info("Cloud data deleted")
                    self.syncStatus = .success
                    // Recreate the zone for future use
                    self.createZoneIfNeeded()
                case .failure(let error):
                    self.logger.error("Delete failed: \(error.localizedDescription)")
                    self.syncStatus = .error(error.localizedDescription)
                }
            }
        }
        privateDB.add(operation)
    }

    // MARK: - Build CKRecords

    private func buildGameStateRecord(persistence: PersistenceManager) -> CKRecord {
        let recordID = CKRecord.ID(recordName: gameStateRecordName, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.userGameState, recordID: recordID)

        let encoder = JSONEncoder()

        if let streakJSON = try? encoder.encode(persistence.loadStreakData()) {
            record["streakDataJSON"] = streakJSON as CKRecordValue
        }
        if let shieldJSON = try? encoder.encode(persistence.loadShieldData()) {
            record["shieldDataJSON"] = shieldJSON as CKRecordValue
        }
        if let profileJSON = try? encoder.encode(persistence.loadProfile()) {
            record["profileJSON"] = profileJSON as CKRecordValue
        }

        return record
    }

    private func buildDailyLogRecord(_ log: DailyLog) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "DailyLog_\(log.dateString)", zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.dailyLog, recordID: recordID)

        record["dateString"] = log.dateString as CKRecordValue

        let encoder = JSONEncoder()
        if let logJSON = try? encoder.encode(log) {
            record["logJSON"] = logJSON as CKRecordValue
        }

        return record
    }

    private func buildTrackedWalkRecord(_ walk: TrackedWalk) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "Walk_\(walk.id.uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.trackedWalk, recordID: recordID)

        record["walkID"] = walk.id.uuidString as CKRecordValue

        let encoder = JSONEncoder()
        if let walkJSON = try? encoder.encode(walk) {
            record["walkJSON"] = walkJSON as CKRecordValue
        }

        return record
    }

    // MARK: - Merge Logic

    private func mergeGameState(remote: CKRecord) {
        isMerging = true
        defer { isMerging = false }

        let decoder = JSONDecoder()
        let persistence = PersistenceManager.shared

        // Merge StreakData: most recent lastGoalMetDate wins for currentStreak; max longestStreak; max consecutiveGoalDays
        if let remoteData = remote["streakDataJSON"] as? Data,
           let remoteStreak = try? decoder.decode(StreakData.self, from: remoteData) {
            var localStreak = persistence.loadStreakData()
            var changed = false

            // Most recent lastGoalMetDate wins for currentStreak + streakStartDate
            let localDate = localStreak.lastGoalMetDate ?? .distantPast
            let remoteDate = remoteStreak.lastGoalMetDate ?? .distantPast
            if remoteDate > localDate {
                localStreak.currentStreak = remoteStreak.currentStreak
                localStreak.lastGoalMetDate = remoteStreak.lastGoalMetDate
                localStreak.streakStartDate = remoteStreak.streakStartDate
                changed = true
            }

            // Max longestStreak
            if remoteStreak.longestStreak > localStreak.longestStreak {
                localStreak.longestStreak = remoteStreak.longestStreak
                changed = true
            }

            // Max consecutiveGoalDays
            if remoteStreak.consecutiveGoalDays > localStreak.consecutiveGoalDays {
                localStreak.consecutiveGoalDays = remoteStreak.consecutiveGoalDays
                changed = true
            }

            if changed {
                persistence.saveStreakData(localStreak)
            }
        }

        // Merge ShieldData: MIN availableShields (prevent duplication exploit);
        // MAX purchasedShields; MAX shieldsUsedThisMonth; most recent lastRefillDate
        if let remoteData = remote["shieldDataJSON"] as? Data,
           let remoteShield = try? decoder.decode(ShieldData.self, from: remoteData) {
            var localShield = persistence.loadShieldData()
            var changed = false

            // MIN availableShields — prevents shield duplication across devices
            if remoteShield.availableShields < localShield.availableShields {
                localShield.availableShields = remoteShield.availableShields
                changed = true
            }

            // MAX purchasedShields (lifetime counter — never decreases)
            if remoteShield.purchasedShields > localShield.purchasedShields {
                localShield.purchasedShields = remoteShield.purchasedShields
                changed = true
            }

            // MAX shieldsUsedThisMonth (usage count — take the higher to avoid under-counting)
            if remoteShield.shieldsUsedThisMonth > localShield.shieldsUsedThisMonth {
                localShield.shieldsUsedThisMonth = remoteShield.shieldsUsedThisMonth
                changed = true
            }

            // MAX totalShieldsUsed (lifetime counter — never decreases)
            if remoteShield.totalShieldsUsed > localShield.totalShieldsUsed {
                localShield.totalShieldsUsed = remoteShield.totalShieldsUsed
                changed = true
            }

            // Most recent lastRefillDate wins (prevents double refill)
            let localRefill = localShield.lastRefillDate ?? .distantPast
            let remoteRefill = remoteShield.lastRefillDate ?? .distantPast
            if remoteRefill > localRefill {
                localShield.lastRefillDate = remoteShield.lastRefillDate
                changed = true
            }

            if changed {
                persistence.saveShieldData(localShield)
            }
        }

        // Merge UserProfile:
        // - Fresh install (local is default): take ALL remote fields
        // - Existing install: local settings win, merge legacyBadges, preserve earliest createdAt
        if let remoteData = remote["profileJSON"] as? Data,
           let remoteProfile = try? decoder.decode(UserProfile.self, from: remoteData) {
            var localProfile = persistence.loadProfile()
            var changed = false

            // Detect fresh install: no onboarding, empty name, no badges
            let isFreshInstall = !localProfile.hasCompletedOnboarding
                && localProfile.displayName.isEmpty
                && localProfile.legacyBadges.isEmpty

            if isFreshInstall {
                // Fresh install — take everything from remote
                localProfile = remoteProfile
                changed = true
            } else {
                // Existing install — selective merge

                // Preserve earliest createdAt
                if remoteProfile.createdAt < localProfile.createdAt {
                    localProfile.createdAt = remoteProfile.createdAt
                    changed = true
                }

                // Union legacyBadges
                let localBadgeIDs = Set(localProfile.legacyBadges.map(\.id))
                let newBadges = remoteProfile.legacyBadges.filter { !localBadgeIDs.contains($0.id) }
                if !newBadges.isEmpty {
                    localProfile.legacyBadges.append(contentsOf: newBadges)
                    changed = true
                }

                // OR merge for boolean flags — never re-show completed onboarding
                if remoteProfile.hasCompletedOnboarding && !localProfile.hasCompletedOnboarding {
                    localProfile.hasCompletedOnboarding = true
                    changed = true
                }
                if remoteProfile.hasSeenFirstWalkEducation && !localProfile.hasSeenFirstWalkEducation {
                    localProfile.hasSeenFirstWalkEducation = true
                    changed = true
                }
            }

            if changed {
                persistence.saveProfile(localProfile)
            }
        }
    }

    private func mergeDailyLog(remote: CKRecord) {
        isMerging = true
        defer { isMerging = false }

        let decoder = JSONDecoder()
        guard let remoteData = remote["logJSON"] as? Data,
              let remoteLog = try? decoder.decode(DailyLog.self, from: remoteData) else { return }

        let persistence = PersistenceManager.shared
        let localLog = persistence.loadDailyLog(for: remoteLog.date)

        if let localLog {
            // Merge: max steps, OR goalMet/shieldUsed, union trackedWalkIDs
            var merged = localLog
            var changed = false

            if remoteLog.steps > merged.steps {
                merged.steps = remoteLog.steps
                changed = true
            }
            if remoteLog.goalMet && !merged.goalMet {
                merged.goalMet = true
                changed = true
            }
            if remoteLog.shieldUsed && !merged.shieldUsed {
                merged.shieldUsed = true
                changed = true
            }

            // Union trackedWalkIDs
            let localIDs = Set(merged.trackedWalkIDs)
            let newIDs = remoteLog.trackedWalkIDs.filter { !localIDs.contains($0) }
            if !newIDs.isEmpty {
                merged.trackedWalkIDs.append(contentsOf: newIDs)
                changed = true
            }

            if changed {
                persistence.saveDailyLog(merged)
            }
        } else {
            // No local log for this date — take the remote one
            persistence.saveDailyLog(remoteLog)
        }
    }

    private func mergeTrackedWalk(remote: CKRecord) {
        isMerging = true
        defer { isMerging = false }

        let decoder = JSONDecoder()
        guard let remoteData = remote["walkJSON"] as? Data,
              let remoteWalk = try? decoder.decode(TrackedWalk.self, from: remoteData) else { return }

        let persistence = PersistenceManager.shared

        // Insert-if-missing (walks are immutable once created)
        if persistence.loadTrackedWalk(by: remoteWalk.id) == nil {
            persistence.saveTrackedWalk(remoteWalk)
        }
    }

    // MARK: - Fetch Helpers

    private func fetchAllRecords(
        ofType recordType: String,
        completion: @escaping ([CKRecord]?, Error?) -> Void
    ) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var allRecords: [CKRecord] = []

        let operation = CKQueryOperation(query: query)
        operation.zoneID = zoneID

        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                allRecords.append(record)
            }
        }

        operation.queryResultBlock = { [weak self] result in
            switch result {
            case .success(let cursor):
                if let cursor {
                    self?.fetchMore(cursor: cursor, accumulated: allRecords, completion: completion)
                } else {
                    completion(allRecords, nil)
                }
            case .failure(let error):
                completion(nil, error)
            }
        }

        privateDB.add(operation)
    }

    private func fetchMore(
        cursor: CKQueryOperation.Cursor,
        accumulated: [CKRecord],
        completion: @escaping ([CKRecord]?, Error?) -> Void
    ) {
        var allRecords = accumulated
        let operation = CKQueryOperation(cursor: cursor)

        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                allRecords.append(record)
            }
        }

        operation.queryResultBlock = { [weak self] result in
            switch result {
            case .success(let nextCursor):
                if let nextCursor {
                    self?.fetchMore(cursor: nextCursor, accumulated: allRecords, completion: completion)
                } else {
                    completion(allRecords, nil)
                }
            case .failure(let error):
                completion(nil, error)
            }
        }

        privateDB.add(operation)
    }

    // MARK: - Reload Managers

    private func reloadManagers() {
        DispatchQueue.main.async {
            let persistence = PersistenceManager.shared
            StreakManager.shared.streakData = persistence.loadStreakData()
            ShieldManager.shared.shieldData = persistence.loadShieldData()
        }
    }
}
