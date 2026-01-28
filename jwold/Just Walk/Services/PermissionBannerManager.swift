//
//  PermissionBannerManager.swift
//  Just Walk
//
//  Manages post-onboarding permission banners with priority logic
//  and 7-day dismissal cooldown.
//

import Foundation
import Combine
import UIKit
import UserNotifications

/// Types of permission banners that can be shown post-onboarding
enum PermissionBannerType: String, CaseIterable, Identifiable {
    case health
    case location
    case notifications

    var id: String { rawValue }

    /// Priority order (lower = higher priority)
    var priority: Int {
        switch self {
        case .health: return 0
        case .location: return 1
        case .notifications: return 2
        }
    }

    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .location: return "location.fill"
        case .notifications: return "bell.fill"
        }
    }

    var title: String {
        switch self {
        case .health: return "Enable Health Access"
        case .location: return "Enable Location"
        case .notifications: return "Enable Notifications"
        }
    }

    var message: String {
        switch self {
        case .health:
            return "Track your steps and distance automatically from Apple Health."
        case .location:
            return "See your walking routes on the map and get location-based features."
        case .notifications:
            return "Get reminders when your streak is at risk and celebrate milestones."
        }
    }

    var actionTitle: String {
        switch self {
        case .health: return "Settings"
        case .location: return "Settings"
        case .notifications: return "Enable"
        }
    }

    /// Whether action opens Settings app or can request permission directly
    var opensSettings: Bool {
        switch self {
        case .health, .location: return true
        case .notifications: return false
        }
    }

    /// UserDefaults key for dismissal timestamp
    var dismissedDateKey: String {
        "permissionBanner_\(rawValue)_dismissedDate"
    }
}

/// Manages permission banner display with priority logic and dismissal cooldown
@MainActor
final class PermissionBannerManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PermissionBannerManager()

    // MARK: - Published State

    @Published private(set) var currentBanner: PermissionBannerType?

    // MARK: - Private Properties

    private let permissionManager = PermissionManager.shared
    private let cooldownDays: Int = 7
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Observe permission status changes
        permissionManager.$healthKitStatus
            .combineLatest(permissionManager.$locationStatus, permissionManager.$notificationStatus)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.evaluate()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Evaluate which banner (if any) should be shown
    func evaluate() {
        // Sort by priority and find the first one that needs attention
        let sortedTypes = PermissionBannerType.allCases.sorted { $0.priority < $1.priority }

        for type in sortedTypes {
            if shouldShowBanner(for: type) {
                currentBanner = type
                return
            }
        }

        // No banner needed
        currentBanner = nil
    }

    /// Dismiss a specific banner type (triggers 7-day cooldown)
    func dismiss(_ type: PermissionBannerType) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: type.dismissedDateKey)
        evaluate()
    }

    /// Handle action button tap for a banner type
    func handleAction(for type: PermissionBannerType) {
        if type.opensSettings {
            openAppSettings()
        } else {
            // Request permission directly (notifications)
            Task {
                await requestNotificationPermission()
            }
        }
    }

    // MARK: - Private Methods

    private func shouldShowBanner(for type: PermissionBannerType) -> Bool {
        // Check if permission is denied/not authorized
        guard isPermissionMissing(for: type) else { return false }

        // Check if within cooldown period
        guard !isInCooldown(for: type) else { return false }

        return true
    }

    private func isPermissionMissing(for type: PermissionBannerType) -> Bool {
        switch type {
        case .health:
            return permissionManager.healthKitStatus == .denied
        case .location:
            return permissionManager.locationStatus == .denied
        case .notifications:
            return permissionManager.notificationStatus == .denied
        }
    }

    private func isInCooldown(for type: PermissionBannerType) -> Bool {
        let dismissedTimestamp = UserDefaults.standard.double(forKey: type.dismissedDateKey)
        guard dismissedTimestamp > 0 else { return false }

        let dismissedDate = Date(timeIntervalSince1970: dismissedTimestamp)
        let daysSinceDismissal = Calendar.current.dateComponents([.day], from: dismissedDate, to: Date()).day ?? 0

        return daysSinceDismissal < cooldownDays
    }

    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                // Re-check status after granting
                await permissionManager.checkCurrentStatus()
            }
        } catch {
            print("❌ PermissionBannerManager: Notification request failed: \(error)")
        }
        evaluate()
    }
}
