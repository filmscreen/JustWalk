//
//  CloudKeyValueStore.swift
//  JustWalk
//
//  Lightweight iCloud Key-Value Store wrapper for fast sync of critical flags.
//  Much faster than full CloudKit (~0.5s vs 5s) - ideal for launch-time checks.
//

import Foundation
import os.log

private let kvsLogger = Logger(subsystem: "onworldtech.JustWalk", category: "KVS")

/// Lightweight iCloud key-value sync for critical app flags.
/// Uses NSUbiquitousKeyValueStore which syncs almost instantly.
enum CloudKeyValueStore {
    private static let store = NSUbiquitousKeyValueStore.default

    // MARK: - Keys

    private enum Key {
        static let hasEverCompletedOnboarding = "hasEverCompletedOnboarding"
    }

    // MARK: - Onboarding Flag

    /// Check if user has ever completed onboarding on any device.
    /// Returns nil if we couldn't determine (store not available).
    static func hasEverCompletedOnboarding() -> Bool? {
        kvsLogger.info("🔑 KVS: Checking hasEverCompletedOnboarding...")

        // Synchronize to get latest from iCloud
        let syncResult = store.synchronize()
        kvsLogger.info("   KVS synchronize() returned: \(syncResult)")

        // Check if the key exists
        if store.object(forKey: Key.hasEverCompletedOnboarding) != nil {
            let value = store.bool(forKey: Key.hasEverCompletedOnboarding)
            kvsLogger.info("   KVS key exists, value: \(value)")
            return value
        }

        // Key doesn't exist - could be new user or store not synced yet
        kvsLogger.info("   KVS key does not exist - returning nil")
        return nil
    }

    /// Mark that user has completed onboarding. Call this when onboarding finishes.
    static func setHasCompletedOnboarding() {
        kvsLogger.info("🔑 KVS: Setting hasEverCompletedOnboarding = true")
        store.set(true, forKey: Key.hasEverCompletedOnboarding)
        let syncResult = store.synchronize()
        kvsLogger.info("   KVS synchronize() returned: \(syncResult)")
    }

    /// Clear all flags (for testing/reset)
    static func clearAll() {
        kvsLogger.info("🔑 KVS: Clearing all flags")
        store.removeObject(forKey: Key.hasEverCompletedOnboarding)
        store.synchronize()
    }
}
