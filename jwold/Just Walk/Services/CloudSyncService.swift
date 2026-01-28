//
//  CloudSyncService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import Combine

/// Manages synchronization of app preferences and lightweight stats to iCloud Key-Value Store.
/// Note: Core workout data is synced via HealthKit. This service handles app-specific settings.
final class CloudSyncService: ObservableObject {
    
    static let shared = CloudSyncService()
    
    private let keyValueStore = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    
    // Keys to sync
    private let syncKeys = [
        "dailyStepGoal",
        "hasCompletedOnboarding",
        "userEmail",
        "newsletterOptIn",
        "appleUserId"
    ]
    
    private init() {
        // Listen for external changes (from other devices or iCloud)
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleCloudChange(notification)
            }
            .store(in: &cancellables)
            
        // Initial sync on launch
        keyValueStore.synchronize()
    }
    
    /// Syncs local changes to iCloud
    func syncLocalToCloud() {
        let defaults = UserDefaults.standard
        
        for key in syncKeys {
            if let value = defaults.object(forKey: key) {
                keyValueStore.set(value, forKey: key)
            }
        }
        
        keyValueStore.synchronize()
        print("☁️ CloudSync: Pushed local data to iCloud")
    }
    
    /// Hnadles data coming from iCloud
    private func handleCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let _ = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        
        // Update local UserDefaults with new cloud values
        let defaults = UserDefaults.standard
        
        for key in changedKeys {
            if syncKeys.contains(key) {
                if let cloudValue = keyValueStore.object(forKey: key) {
                    defaults.set(cloudValue, forKey: key)
                    print("☁️ CloudSync: Updated local key '\(key)' from iCloud")
                }
            }
        }
    }
}
