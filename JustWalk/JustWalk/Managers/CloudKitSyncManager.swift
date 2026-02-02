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
        static let foodLog = "FoodLog"
        static let calorieGoalSettings = "CalorieGoalSettings"
    }

    // Fixed record IDs for single-instance records
    private let gameStateRecordName = "UserGameState_v1"
    private let userSettingsRecordKey = "userSettingsJSON"
    private let milestoneStateRecordKey = "milestoneStateJSON"

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

    var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }

    private init() {
        container = CKContainer(identifier: "iCloud.onworldtech.JustWalk")
        privateDB = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "JustWalkZone", ownerName: CKCurrentUserDefaultName)

        UserDefaults.standard.register(defaults: [
            "iCloudSyncEnabled": true
        ])
    }

    // Track zone creation state
    private var zoneReady = false
    private var pendingPushAfterZone = false
    private var observersRegistered = false

    // MARK: - Error Logging Helper

    private func logCKError(_ error: Error, context: String) {
        if let ckError = error as? CKError {
            logger.error("❌ \(context): CKError code=\(ckError.code.rawValue) - \(ckError.localizedDescription)")

            switch ckError.code {
            case .zoneNotFound:
                logger.error("   🔴 ZONE NOT FOUND - CloudKit zone was never created!")
            case .unknownItem:
                logger.error("   🔴 UNKNOWN ITEM - Record doesn't exist in CloudKit")
            case .networkFailure:
                logger.error("   🔴 NETWORK FAILURE - Check internet connection")
            case .networkUnavailable:
                logger.error("   🔴 NETWORK UNAVAILABLE - No network")
            case .serviceUnavailable:
                logger.error("   🔴 SERVICE UNAVAILABLE - CloudKit is down")
            case .notAuthenticated:
                logger.error("   🔴 NOT AUTHENTICATED - User not signed into iCloud!")
            case .permissionFailure:
                logger.error("   🔴 PERMISSION FAILURE - Check entitlements!")
            case .serverRecordChanged:
                logger.error("   🔴 SERVER RECORD CHANGED - Conflict detected")
            case .partialFailure:
                if let partialErrors = ckError.partialErrorsByItemID {
                    for (itemID, itemError) in partialErrors {
                        logger.error("   🔴 Partial error for \(itemID): \(itemError.localizedDescription)")
                    }
                }
            default:
                logger.error("   🔴 Other CKError code: \(ckError.code.rawValue)")
            }
        } else {
            logger.error("❌ \(context): Non-CK error - \(error.localizedDescription)")
        }
    }

    // MARK: - Setup

    /// Sets up CloudKit sync. Returns true if setup succeeded, false otherwise.
    /// IMPORTANT: This is now async and WAITS for zone creation to complete.
    @discardableResult
    func setup() async -> Bool {
        logger.info("🔧 CloudKit setup() called")
        guard isSyncEnabled else {
            logger.warning("⚠️ CloudKit sync is DISABLED - skipping setup")
            return false
        }
        logger.info("✅ CloudKit sync is enabled, proceeding with setup")

        // WAIT for zone creation to complete before proceeding
        let zoneCreated = await createZoneIfNeeded()
        guard zoneCreated else {
            logger.error("❌ Zone creation failed - cannot proceed with CloudKit sync")
            return false
        }

        // Zone is ready - set up notification observers
        await MainActor.run {
            zoneReady = true
            observePersistenceNotifications()
        }

        logger.info("✅ CloudKit setup complete - zone exists, observers registered")
        return true
    }

    /// Synchronous setup for backward compatibility - use async version when possible
    func setupSync() {
        Task {
            await setup()
        }
    }

    /// Creates the CloudKit zone if it doesn't exist. Returns true on success.
    private func createZoneIfNeeded() async -> Bool {
        logger.info("📦 Creating CloudKit zone: \(self.zoneID.zoneName)")

        // First check if zone already exists
        do {
            let existingZones = try await privateDB.allRecordZones()
            if existingZones.contains(where: { $0.zoneID.zoneName == zoneID.zoneName }) {
                logger.info("✅ Zone already exists: \(self.zoneID.zoneName)")
                return true
            }
        } catch {
            logger.error("❌ Failed to check existing zones: \(error.localizedDescription)")
            // Continue to try creating the zone anyway
        }

        // Zone doesn't exist, create it
        do {
            let zone = CKRecordZone(zoneID: zoneID)
            _ = try await privateDB.save(zone)
            logger.info("✅ CloudKit zone created: \(self.zoneID.zoneName)")
            return true
        } catch {
            // Check if it's a "zone already exists" error - that's fine
            if let ckError = error as? CKError {
                // partialFailure with zoneExists or serverRecordChanged means zone exists
                if ckError.code == .serverRecordChanged || ckError.code == .partialFailure {
                    logger.info("ℹ️ Zone already exists (from error), treating as success")
                    return true
                }
            }
            logger.error("❌ Failed to create zone: \(error.localizedDescription)")
            logCKError(error, context: "Zone creation")
            return false
        }
    }

    private func observePersistenceNotifications() {
        // Prevent registering observers multiple times
        guard !observersRegistered else {
            logger.info("ℹ️ Observers already registered, skipping")
            return
        }
        observersRegistered = true

        // Critical data gets immediate push (no debounce - can't risk losing this data)
        let criticalNames: [Notification.Name] = [
            .didSaveTrackedWalk,  // Walk history is irreplaceable
            .didSaveShieldData,   // Shield balance must sync immediately (prevents duplication/loss)
            .didSaveDailyLog,     // Goal status & shield usage per day is critical for streak integrity
            .didSaveFoodLog,      // Food logs should sync immediately to preserve meal tracking
            .didSaveCalorieGoal   // Calorie goal settings must sync to preserve across devices
        ]
        for name in criticalNames {
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, !self.isMerging else { return }
                // Push immediately - critical data that must sync ASAP
                self.pushAllToCloud()
            }
        }

        // Less critical data uses debounced push (reduces API calls)
        let debouncedNames: [Notification.Name] = [
            .didSaveStreakData,  // Can be recalculated from DailyLogs
            .didSaveProfile      // User preferences, not critical
        ]
        for name in debouncedNames {
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
        guard isSyncEnabled else { return }
        pushWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.pushAllToCloud()
        }
        pushWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    // MARK: - Zone Verification

    /// Debug function to check if our CloudKit zone exists
    func verifyZoneExists() async -> Bool {
        logger.info("🔍 Verifying zone exists...")

        do {
            let zones = try await privateDB.allRecordZones()
            logger.info("   Found \(zones.count) zones in private database:")
            for zone in zones {
                logger.info("   - \(zone.zoneID.zoneName)")
            }

            let ourZoneExists = zones.contains { $0.zoneID.zoneName == zoneID.zoneName }
            if ourZoneExists {
                logger.info("   ✅ Our zone '\(self.zoneID.zoneName)' EXISTS")
            } else {
                logger.error("   ❌ Our zone '\(self.zoneID.zoneName)' NOT FOUND!")
            }
            return ourZoneExists
        } catch {
            logCKError(error, context: "Zone verification")
            return false
        }
    }

    // MARK: - Quick Check for Existing Data

    /// Quickly checks if any CloudKit data exists (2-3 second timeout).
    /// Used during launch to determine if user is returning without waiting for full sync.
    /// Returns true if GameState record exists, false if not found or on error/timeout.
    func quickCheckForExistingData() async -> Bool {
        guard isSyncEnabled else {
            logger.info("🔍 Quick check: sync disabled")
            return false
        }

        logger.info("🔍 Quick check: starting CloudKit lookup...")
        logger.info("   Zone: \(self.zoneID.zoneName)")
        logger.info("   Record name: \(self.gameStateRecordName)")

        // First check iCloud account status
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                logger.info("   ✅ iCloud account: available")
            case .noAccount:
                logger.warning("   ⚠️ iCloud account: NO ACCOUNT - user not signed in!")
                return false
            case .restricted:
                logger.warning("   ⚠️ iCloud account: restricted")
                return false
            case .couldNotDetermine:
                logger.warning("   ⚠️ iCloud account: could not determine status")
            case .temporarilyUnavailable:
                logger.warning("   ⚠️ iCloud account: temporarily unavailable")
            @unknown default:
                logger.warning("   ⚠️ iCloud account: unknown status")
            }
        } catch {
            logger.error("   ❌ Failed to check iCloud account: \(error.localizedDescription)")
        }

        // Verify zone exists before trying to fetch records
        let zoneExists = await verifyZoneExists()
        if !zoneExists {
            logger.error("🔍 Quick check: Zone doesn't exist - data was never pushed!")
            return false
        }

        // Use actor isolation to safely track continuation state
        let result: Bool = await withCheckedContinuation { continuation in
            let gameStateRecordID = CKRecord.ID(recordName: gameStateRecordName, zoneID: zoneID)

            // Create fetch operation with short timeout
            let operation = CKFetchRecordsOperation(recordIDs: [gameStateRecordID])
            operation.desiredKeys = [] // We just need to know if it exists, don't fetch data
            operation.qualityOfService = .userInitiated

            // Track if we've already resumed to prevent double-resume crash
            var hasResumed = false
            let lock = NSLock()

            func safeResume(_ value: Bool, reason: String) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                self.logger.info("Quick check: \(reason) - returning \(value)")
                continuation.resume(returning: value)
            }

            var foundRecord = false

            operation.perRecordResultBlock = { [weak self] recordID, result in
                switch result {
                case .success:
                    foundRecord = true
                    self?.logger.info("🔍 Quick check: ✅ FOUND existing record: \(recordID.recordName)")
                case .failure(let error):
                    self?.logCKError(error, context: "Quick check per-record")
                }
            }

            operation.fetchRecordsResultBlock = { [weak self] result in
                switch result {
                case .success:
                    if foundRecord {
                        self?.logger.info("🔍 Quick check: ✅ Fetch succeeded, record exists")
                    } else {
                        self?.logger.info("🔍 Quick check: ⚠️ Fetch succeeded but no record found")
                    }
                    safeResume(foundRecord, reason: "fetch completed")
                case .failure(let error):
                    self?.logCKError(error, context: "Quick check fetch")
                    safeResume(false, reason: "fetch error")
                }
            }

            // Add timeout - if CloudKit doesn't respond in 3 seconds, assume no data
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                operation.cancel()
                safeResume(false, reason: "timeout after 3s")
            }

            self.privateDB.add(operation)
        }

        return result
    }

    // MARK: - Force Sync (push + pull)

    func forceSync() {
        guard isSyncEnabled else { return }
        pushAllToCloud()
        // Pull after a brief delay to let the push settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.pullFromCloud()
        }
    }

    // MARK: - Push All To Cloud

    func pushAllToCloud() {
        logger.info("📤 pushAllToCloud() called")
        guard isSyncEnabled else {
            logger.warning("⚠️ pushAllToCloud: sync is DISABLED")
            return
        }

        // If zone isn't ready yet, queue the push for later
        if !zoneReady {
            logger.info("⏳ Zone not ready yet, queuing push for after zone creation")
            pendingPushAfterZone = true
            return
        }

        // Cancel any pending debounced push to avoid double-push
        pushWorkItem?.cancel()

        guard !isSyncing else {
            logger.info("⏳ Already syncing, skipping push")
            return
        }
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

        // Log which days have shields for debugging
        let shieldedLogs = dailyLogs.filter { $0.shieldUsed }
        if !shieldedLogs.isEmpty {
            logger.info("🛡️ Pushing \(shieldedLogs.count) shielded day(s):")
            for log in shieldedLogs {
                logger.info("   🛡️ \(log.dateString): shieldUsed=true, goalMet=\(log.goalMet), steps=\(log.steps)")
            }
        }

        // Build tracked walk records (ALL walks — no cutoff)
        let walks = persistence.loadAllTrackedWalks()
        let walkRecords = walks.map { buildTrackedWalkRecord($0) }

        // Build food log records (ALL food logs — no cutoff)
        let foodLogs = persistence.loadAllFoodLogs()
        let foodLogRecords = foodLogs.map { buildFoodLogRecord($0) }

        // Build calorie goal settings record (if exists)
        var calorieGoalRecords: [CKRecord] = []
        if let calorieGoalSettings = persistence.loadCalorieGoalSettings() {
            calorieGoalRecords.append(buildCalorieGoalSettingsRecord(calorieGoalSettings))
        }

        // Combine all records
        let allRecords = [gameStateRecord] + logRecords + walkRecords + foodLogRecords + calorieGoalRecords

        logger.info("📊 Pushing \(allRecords.count) total records (1 gameState, \(logRecords.count) logs, \(walkRecords.count) walks, \(foodLogRecords.count) foodLogs, \(calorieGoalRecords.count) calorieGoal)")

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
                    self?.logger.info("✅ Pushed batch of \(batch.count) records successfully")
                case .failure(let error):
                    self?.logger.error("❌ Push FAILED: \(error.localizedDescription)")
                    // Log specific CloudKit error details
                    if let ckError = error as? CKError {
                        self?.logger.error("   CKError code: \(ckError.code.rawValue)")
                        if let partialErrors = ckError.partialErrorsByItemID {
                            for (itemID, itemError) in partialErrors {
                                self?.logger.error("   Partial error for \(itemID): \(itemError.localizedDescription)")
                            }
                        }
                    }
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
                self.logger.error("❌ Push completed with errors: \(error.localizedDescription)")
                self.syncStatus = .error(error.localizedDescription)
                self.scheduleRetry()
            } else {
                self.logger.info("✅ Push completed successfully!")
                self.syncStatus = .success
                self.lastSyncDate = Date()
                self.retryCount = 0
                self.pendingRetry = false
            }
        }
    }

    // MARK: - Pull From Cloud

    func pullFromCloud() {
        guard isSyncEnabled else { return }
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
                self?.logger.info("📥 Pulled \(records.count) daily log records from CloudKit")
                for record in records {
                    self?.mergeDailyLog(remote: record)
                }
            } else if let error {
                self?.logger.error("Pull daily logs failed: \(error.localizedDescription)")
                self?.logCKError(error, context: "Pull daily logs")
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

        // 4. Fetch all food logs
        group.enter()
        fetchAllRecords(ofType: RecordType.foodLog) { [weak self] records, error in
            if let records {
                self?.logger.info("📥 Pulled \(records.count) food log records from CloudKit")
                for record in records {
                    self?.mergeFoodLog(remote: record)
                }
            } else if let error {
                self?.logger.error("Pull food logs failed: \(error.localizedDescription)")
                self?.logCKError(error, context: "Pull food logs")
                pullError = error
            }
            group.leave()
        }

        // 5. Fetch calorie goal settings
        group.enter()
        fetchAllRecords(ofType: RecordType.calorieGoalSettings) { [weak self] records, error in
            if let records {
                self?.logger.info("📥 Pulled \(records.count) calorie goal settings records from CloudKit")
                // Only merge the first one (there should only be one)
                if let record = records.first {
                    self?.mergeCalorieGoalSettings(remote: record)
                }
            } else if let error {
                self?.logger.error("Pull calorie goal settings failed: \(error.localizedDescription)")
                self?.logCKError(error, context: "Pull calorie goal settings")
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

    // MARK: - Delete Individual Records from CloudKit

    /// Deletes a FoodLog record from CloudKit when deleted locally
    func deleteFoodLogFromCloud(logID: String) {
        guard isSyncEnabled else { return }

        let recordID = CKRecord.ID(recordName: "FoodLog_\(logID)", zoneID: zoneID)
        let operation = CKModifyRecordsOperation(recordIDsToDelete: [recordID])
        operation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🗑️ Deleted FoodLog from CloudKit: \(logID)")
            case .failure(let error):
                self?.logger.error("❌ Failed to delete FoodLog from CloudKit: \(error.localizedDescription)")
            }
        }
        privateDB.add(operation)
    }

    /// Deletes CalorieGoalSettings record from CloudKit when deleted locally
    func deleteCalorieGoalSettingsFromCloud(settingsID: String) {
        guard isSyncEnabled else { return }

        let recordID = CKRecord.ID(recordName: "CalorieGoalSettings_\(settingsID)", zoneID: zoneID)
        let operation = CKModifyRecordsOperation(recordIDsToDelete: [recordID])
        operation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                self?.logger.info("🗑️ Deleted CalorieGoalSettings from CloudKit: \(settingsID)")
            case .failure(let error):
                self?.logger.error("❌ Failed to delete CalorieGoalSettings from CloudKit: \(error.localizedDescription)")
            }
        }
        privateDB.add(operation)
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
                    Task {
                        _ = await self.createZoneIfNeeded()
                    }
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

        let shieldData = persistence.loadShieldData()
        logger.info("🛡️ buildGameStateRecord: Pushing shieldData with availableShields=\(shieldData.availableShields)")
        if let shieldJSON = try? encoder.encode(shieldData) {
            record["shieldDataJSON"] = shieldJSON as CKRecordValue
        }
        if let profileJSON = try? encoder.encode(persistence.loadProfile()) {
            record["profileJSON"] = profileJSON as CKRecordValue
        }
        if let settingsJSON = try? encoder.encode(buildUserSettingsSnapshot()) {
            record[userSettingsRecordKey] = settingsJSON as CKRecordValue
        }
        if let milestoneJSON = try? encoder.encode(MilestoneManager.shared.exportState()) {
            record[milestoneStateRecordKey] = milestoneJSON as CKRecordValue
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

    private func buildFoodLogRecord(_ log: FoodLog) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "FoodLog_\(log.logID)", zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.foodLog, recordID: recordID)

        // Map all FoodLog properties to CloudKit fields
        record["logID"] = log.logID as CKRecordValue
        record["date"] = log.date as CKRecordValue
        record["mealType"] = log.mealType.rawValue as CKRecordValue
        record["name"] = log.name as CKRecordValue
        record["entryDescription"] = log.entryDescription as CKRecordValue
        record["calories"] = log.calories as CKRecordValue
        record["protein"] = log.protein as CKRecordValue
        record["carbs"] = log.carbs as CKRecordValue
        record["fat"] = log.fat as CKRecordValue
        record["source"] = log.source.rawValue as CKRecordValue
        record["createdAt"] = log.createdAt as CKRecordValue
        record["modifiedAt"] = log.modifiedAt as CKRecordValue

        return record
    }

    private func buildCalorieGoalSettingsRecord(_ settings: CalorieGoalSettings) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "CalorieGoalSettings_\(settings.settingsID)", zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.calorieGoalSettings, recordID: recordID)

        record["settingsID"] = settings.settingsID as CKRecordValue
        record["dailyGoal"] = settings.dailyGoal as CKRecordValue
        record["calculatedMaintenance"] = settings.calculatedMaintenance as CKRecordValue
        record["sex"] = settings.sex.rawValue as CKRecordValue
        record["age"] = settings.age as CKRecordValue
        record["heightCM"] = settings.heightCM as CKRecordValue
        record["weightKG"] = settings.weightKG as CKRecordValue
        record["activityLevel"] = settings.activityLevel.rawValue as CKRecordValue
        record["createdAt"] = settings.createdAt as CKRecordValue
        record["modifiedAt"] = settings.modifiedAt as CKRecordValue

        return record
    }

    // MARK: - Merge Logic

    private func mergeGameState(remote: CKRecord) {
        logger.info("📥 mergeGameState() called - starting restore from CloudKit")
        isMerging = true
        defer { isMerging = false }

        let decoder = JSONDecoder()
        let persistence = PersistenceManager.shared
        let localProfile = persistence.loadProfile()
        let isFreshInstall = !localProfile.hasCompletedOnboarding
            && localProfile.displayName.isEmpty
            && localProfile.legacyBadges.isEmpty

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

        // Merge ShieldData: Fresh install takes remote values; otherwise MIN availableShields
        // (prevent duplication exploit); MAX purchasedShields; MAX shieldsUsedThisMonth; most recent lastRefillDate
        if let remoteData = remote["shieldDataJSON"] as? Data,
           let remoteShield = try? decoder.decode(ShieldData.self, from: remoteData) {
            var localShield = persistence.loadShieldData()
            var changed = false

            logger.info("🛡️ Shield merge: remote availableShields=\(remoteShield.availableShields), local availableShields=\(localShield.availableShields)")
            logger.info("🛡️ Shield merge: remote lastRefillDate=\(String(describing: remoteShield.lastRefillDate)), local lastRefillDate=\(String(describing: localShield.lastRefillDate))")

            // Detect fresh install: local has no lastRefillDate (never initialized)
            let isLocalFreshInstall = localShield.lastRefillDate == nil

            if isLocalFreshInstall {
                // Fresh install — take ALL remote shield data
                logger.info("🛡️ Shield merge: Fresh install detected, taking remote values (availableShields=\(remoteShield.availableShields))")
                localShield = remoteShield
                changed = true
            } else {
                // Existing install — use defensive merge logic

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

                // If we restored a completed onboarding state, also set the KVS flag
                // so future reinstalls will be detected immediately without CloudKit check
                if localProfile.hasCompletedOnboarding {
                    CloudKeyValueStore.setHasCompletedOnboarding()
                }
            }
        }

        // Merge user settings (notifications, haptics, voice, education flags, usage counters, etc.)
        if let settingsData = remote[userSettingsRecordKey] as? Data,
           let remoteSettings = try? decoder.decode(CloudUserSettings.self, from: settingsData) {
            applyUserSettings(remoteSettings, isFreshInstall: isFreshInstall)
        }

        // Merge milestone state
        if let milestoneData = remote[milestoneStateRecordKey] as? Data,
           let remoteMilestones = try? decoder.decode(MilestoneManager.MilestoneState.self, from: milestoneData) {
            MilestoneManager.shared.mergeFromCloud(remoteMilestones, isFreshInstall: isFreshInstall)
        }
    }

    private func mergeDailyLog(remote: CKRecord) {
        isMerging = true
        defer { isMerging = false }

        let decoder = JSONDecoder()
        guard let remoteData = remote["logJSON"] as? Data,
              let remoteLog = try? decoder.decode(DailyLog.self, from: remoteData) else {
            logger.error("❌ Failed to decode DailyLog from CloudKit record")
            return
        }

        // Log if this is a shielded day being restored
        if remoteLog.shieldUsed {
            logger.info("🛡️ Restoring shielded day: \(remoteLog.dateString) (shieldUsed=true, goalMet=\(remoteLog.goalMet), steps=\(remoteLog.steps))")
        }

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
                logger.info("   🛡️ Merged shieldUsed=true for \(remoteLog.dateString)")
            }
            if merged.goalTarget == nil, let remoteGoal = remoteLog.goalTarget {
                merged.goalTarget = remoteGoal
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
            if remoteLog.shieldUsed {
                logger.info("   🛡️ Saving new shielded day: \(remoteLog.dateString)")
            }
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

    private func mergeFoodLog(remote: CKRecord) {
        isMerging = true
        defer { isMerging = false }

        // Extract fields from CloudKit record
        guard let logID = remote["logID"] as? String,
              let date = remote["date"] as? Date,
              let mealTypeRaw = remote["mealType"] as? String,
              let name = remote["name"] as? String,
              let createdAt = remote["createdAt"] as? Date,
              let modifiedAt = remote["modifiedAt"] as? Date else {
            logger.error("❌ Failed to decode FoodLog from CloudKit record - missing required fields")
            return
        }

        let entryDescription = remote["entryDescription"] as? String ?? ""
        let calories = remote["calories"] as? Int ?? 0
        let protein = remote["protein"] as? Int ?? 0
        let carbs = remote["carbs"] as? Int ?? 0
        let fat = remote["fat"] as? Int ?? 0
        let sourceRaw = remote["source"] as? String ?? "manual"

        let mealType = MealType(rawValue: mealTypeRaw) ?? .unspecified
        let source = EntrySource(rawValue: sourceRaw) ?? .manual

        // Create the FoodLog from CloudKit fields
        let remoteLog = FoodLog(
            id: UUID(uuidString: logID) ?? UUID(),
            logID: logID,
            date: date,
            mealType: mealType,
            name: name,
            entryDescription: entryDescription,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            source: source,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )

        let persistence = PersistenceManager.shared
        let localLog = persistence.loadFoodLog(by: remoteLog.id)

        if let localLog {
            // Merge: last-write-wins based on modifiedAt
            if remoteLog.modifiedAt > localLog.modifiedAt {
                persistence.saveFoodLog(remoteLog)
                logger.info("📥 Updated FoodLog from CloudKit: \(remoteLog.name)")
            }
        } else {
            // No local log — insert the remote one
            persistence.saveFoodLog(remoteLog)
            logger.info("📥 Restored FoodLog from CloudKit: \(remoteLog.name)")
        }
    }

    private func mergeCalorieGoalSettings(remote: CKRecord) {
        isMerging = true
        defer { isMerging = false }

        // Extract fields from CloudKit record
        guard let settingsID = remote["settingsID"] as? String,
              let dailyGoal = remote["dailyGoal"] as? Int,
              let calculatedMaintenance = remote["calculatedMaintenance"] as? Int,
              let sexRaw = remote["sex"] as? String,
              let age = remote["age"] as? Int,
              let heightCM = remote["heightCM"] as? Double,
              let weightKG = remote["weightKG"] as? Double,
              let activityLevelRaw = remote["activityLevel"] as? String,
              let createdAt = remote["createdAt"] as? Date,
              let modifiedAt = remote["modifiedAt"] as? Date else {
            logger.error("❌ Failed to decode CalorieGoalSettings from CloudKit record - missing required fields")
            return
        }

        guard let sex = BiologicalSex(rawValue: sexRaw),
              let activityLevel = ActivityLevel(rawValue: activityLevelRaw) else {
            logger.error("❌ Failed to decode CalorieGoalSettings enums from CloudKit")
            return
        }

        let remoteSettings = CalorieGoalSettings(
            id: UUID(uuidString: settingsID) ?? UUID(),
            settingsID: settingsID,
            dailyGoal: dailyGoal,
            calculatedMaintenance: calculatedMaintenance,
            sex: sex,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            activityLevel: activityLevel,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )

        let persistence = PersistenceManager.shared
        let localSettings = persistence.loadCalorieGoalSettings()

        if let localSettings {
            // Merge: last-write-wins based on modifiedAt
            if remoteSettings.modifiedAt > localSettings.modifiedAt {
                persistence.saveCalorieGoalSettings(remoteSettings)
                logger.info("📥 Updated CalorieGoalSettings from CloudKit: \(remoteSettings.dailyGoal) cal")
            }
        } else {
            // No local settings — insert the remote one
            persistence.saveCalorieGoalSettings(remoteSettings)
            logger.info("📥 Restored CalorieGoalSettings from CloudKit: \(remoteSettings.dailyGoal) cal")
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

            // Invalidate caches so restored walks/logs are visible immediately
            persistence.invalidateCaches()

            // Reload managers with fresh data from persistence
            // Use load() which recalculates streak from daily logs for accuracy
            StreakManager.shared.load()
            ShieldManager.shared.shieldData = persistence.loadShieldData()
            FoodLogManager.shared.refreshFromPersistence()
            CalorieGoalManager.shared.refreshFromPersistence()

            // Post notification so UI can refresh (e.g., walk history, day details)
            NotificationCenter.default.post(name: .didCompleteCloudSync, object: nil)
        }
    }
}

// MARK: - Cloud Sync Notifications

extension Notification.Name {
    /// Posted when CloudKit sync completes (pull or push).
    /// UI should refresh to show any restored data.
    static let didCompleteCloudSync = Notification.Name("didCompleteCloudSync")

    /// Posted when user deletes all data.
    /// App should reset to onboarding state.
    static let didDeleteAllData = Notification.Name("didDeleteAllData")
}

// MARK: - User Settings Snapshot

private struct CloudUserSettings: Codable {
    var notifications: NotificationSettings
    var haptics: HapticsSettings
    var liveActivity: LiveActivitySettings
    var education: EducationSettings
    var userAge: Int?
    var intervalUsage: IntervalUsageData
    var fatBurnUsage: FatBurnUsageData
}

private struct NotificationSettings: Codable {
    var isEnabled: Bool
    var streakRemindersEnabled: Bool
    var streakReminderHour: Int
    var streakReminderMinute: Int
    var goalCelebrationsEnabled: Bool
}

private struct HapticsSettings: Codable {
    var isEnabled: Bool
    var goalReachedHaptic: Bool
    var stepMilestoneHaptic: Bool
}

private struct LiveActivitySettings: Codable {
    var isEnabled: Bool
    var promptShown: Bool
}

private struct EducationSettings: Codable {
    var hasSeenIntervalsEducation: Bool
    var hasSeenFatBurnEducation: Bool
    var hasSeenPostMealEducation: Bool
    var hasSeenGuidedWalksIntent: Bool
    var guidedWalksIntent: String
    var hasSeenStreakMilestoneProPrompt: Bool
    var preflightSeen: [String: Bool]
}

private extension CloudKitSyncManager {
    func buildUserSettingsSnapshot() -> CloudUserSettings {
        let defaults = UserDefaults.standard

        let preflightSeen: [String: Bool] = Dictionary(uniqueKeysWithValues:
            IntervalProgram.allCases.map { program in
                let key = "hasSeenPreFlight_\(program.rawValue)"
                return (program.rawValue, defaults.bool(forKey: key))
            }
        )

        return CloudUserSettings(
            notifications: NotificationSettings(
                isEnabled: defaults.bool(forKey: "notif_isEnabled"),
                streakRemindersEnabled: defaults.bool(forKey: "notif_streakReminders"),
                streakReminderHour: defaults.integer(forKey: "notif_streakReminderHour"),
                streakReminderMinute: defaults.integer(forKey: "notif_streakReminderMinute"),
                goalCelebrationsEnabled: defaults.bool(forKey: "notif_goalCelebrations")
            ),
            haptics: HapticsSettings(
                isEnabled: defaults.bool(forKey: "haptics_isEnabled"),
                goalReachedHaptic: defaults.bool(forKey: "haptics_goalReached"),
                stepMilestoneHaptic: defaults.bool(forKey: "haptics_stepMilestone")
            ),
            liveActivity: LiveActivitySettings(
                isEnabled: defaults.bool(forKey: "liveActivity_isEnabled"),
                promptShown: defaults.bool(forKey: "liveActivity_promptShown")
            ),
            education: EducationSettings(
                hasSeenIntervalsEducation: defaults.bool(forKey: "hasSeenIntervalsEducation"),
                hasSeenFatBurnEducation: defaults.bool(forKey: "hasSeenFatBurnEducation"),
                hasSeenPostMealEducation: defaults.bool(forKey: "hasSeenPostMealEducation"),
                hasSeenGuidedWalksIntent: defaults.bool(forKey: "hasSeenGuidedWalksIntent"),
                guidedWalksIntent: defaults.string(forKey: "guidedWalksIntent") ?? "exploring",
                hasSeenStreakMilestoneProPrompt: defaults.bool(forKey: "hasSeenStreakMilestoneProPrompt"),
                preflightSeen: preflightSeen
            ),
            userAge: defaults.object(forKey: "userAge") as? Int,
            intervalUsage: PersistenceManager.shared.loadIntervalUsage(),
            fatBurnUsage: PersistenceManager.shared.loadFatBurnUsage()
        )
    }

    func applyUserSettings(_ remote: CloudUserSettings, isFreshInstall: Bool) {
        let defaults = UserDefaults.standard

        // Usage: keep the higher usage for the current week
        var localInterval = PersistenceManager.shared.loadIntervalUsage()
        if remote.intervalUsage.weekStartDate > localInterval.weekStartDate {
            localInterval = remote.intervalUsage
        } else if remote.intervalUsage.weekStartDate == localInterval.weekStartDate {
            localInterval.intervalsUsedThisWeek = max(
                localInterval.intervalsUsedThisWeek,
                remote.intervalUsage.intervalsUsedThisWeek
            )
        }
        PersistenceManager.shared.saveIntervalUsage(localInterval)

        var localFatBurn = PersistenceManager.shared.loadFatBurnUsage()
        if remote.fatBurnUsage.weekStartDate > localFatBurn.weekStartDate {
            localFatBurn = remote.fatBurnUsage
        } else if remote.fatBurnUsage.weekStartDate == localFatBurn.weekStartDate {
            localFatBurn.fatBurnsUsedThisWeek = max(
                localFatBurn.fatBurnsUsedThisWeek,
                remote.fatBurnUsage.fatBurnsUsedThisWeek
            )
        }
        PersistenceManager.shared.saveFatBurnUsage(localFatBurn)

        // Education flags (never overwrite true with false)
        if remote.education.hasSeenIntervalsEducation {
            defaults.set(true, forKey: "hasSeenIntervalsEducation")
        }
        if remote.education.hasSeenFatBurnEducation {
            defaults.set(true, forKey: "hasSeenFatBurnEducation")
        }
        if remote.education.hasSeenPostMealEducation {
            defaults.set(true, forKey: "hasSeenPostMealEducation")
        }
        if remote.education.hasSeenGuidedWalksIntent {
            defaults.set(true, forKey: "hasSeenGuidedWalksIntent")
        }
        if remote.education.hasSeenStreakMilestoneProPrompt {
            defaults.set(true, forKey: "hasSeenStreakMilestoneProPrompt")
        }
        for (programRaw, seen) in remote.education.preflightSeen where seen {
            defaults.set(true, forKey: "hasSeenPreFlight_\(programRaw)")
        }

        // Guided walks intent: only overwrite if fresh or local is default
        let localGuidedIntent = defaults.string(forKey: "guidedWalksIntent") ?? "exploring"
        if isFreshInstall || localGuidedIntent == "exploring" {
            defaults.set(remote.education.guidedWalksIntent, forKey: "guidedWalksIntent")
        }

        // User age
        if isFreshInstall, let remoteAge = remote.userAge {
            defaults.set(remoteAge, forKey: "userAge")
        }

        // Preferences: apply only on fresh install to avoid overriding device-specific toggles
        guard isFreshInstall else { return }

        NotificationManager.shared.isEnabled = remote.notifications.isEnabled
        NotificationManager.shared.streakRemindersEnabled = remote.notifications.streakRemindersEnabled
        NotificationManager.shared.streakReminderHour = remote.notifications.streakReminderHour
        NotificationManager.shared.streakReminderMinute = remote.notifications.streakReminderMinute
        NotificationManager.shared.goalCelebrationsEnabled = remote.notifications.goalCelebrationsEnabled

        HapticsManager.shared.isEnabled = remote.haptics.isEnabled
        HapticsManager.shared.goalReachedHaptic = remote.haptics.goalReachedHaptic
        HapticsManager.shared.stepMilestoneHaptic = remote.haptics.stepMilestoneHaptic

        LiveActivityManager.shared.isEnabled = remote.liveActivity.isEnabled
        defaults.set(remote.liveActivity.promptShown, forKey: "liveActivity_promptShown")
    }
}
