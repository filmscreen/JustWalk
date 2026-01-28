//
//  NotificationPermissionManager.swift
//  Just Walk
//
//  Centralized service for managing notification permission state and smart prompting.
//

import SwiftUI
import UserNotifications
import Combine

/// Manages notification permission state and smart prompting logic
@MainActor
final class NotificationPermissionManager: ObservableObject {
    static let shared = NotificationPermissionManager()

    // MARK: - Published State

    /// Current notification authorization status
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Persistent State

    /// Timestamp when user tapped "Not Now" (for 30-day cooldown)
    @AppStorage("notificationPromptDismissedDate") private var dismissedDateTimestamp: Double = 0

    /// Whether the prompt has ever been shown
    @AppStorage("hasShownNotificationPrompt") private var hasShownPrompt: Bool = false

    /// Whether the 30-day re-prompt banner was dismissed
    @AppStorage("notificationBannerDismissed") private var bannerDismissed: Bool = false

    // MARK: - Computed Properties

    /// Whether notifications are currently authorized
    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Whether user has denied notifications
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    /// Whether we should show the 30-day re-prompt banner
    var shouldShowRePromptBanner: Bool {
        // Only show if:
        // 1. Previously dismissed (not denied via system)
        // 2. 30+ days have passed
        // 3. Still not determined (user never saw system prompt)
        // 4. Banner hasn't been dismissed
        guard authorizationStatus == .notDetermined else { return false }
        guard dismissedDateTimestamp > 0 else { return false }
        guard !bannerDismissed else { return false }

        let dismissedDate = Date(timeIntervalSince1970: dismissedDateTimestamp)
        let daysSinceDismiss = Calendar.current.dateComponents([.day], from: dismissedDate, to: Date()).day ?? 0
        return daysSinceDismiss >= 30
    }

    // MARK: - Initialization

    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization Check

    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Smart Prompt Logic

    /// Determines if we should show the notification permission prompt
    /// Smart triggers:
    /// - First goal completed (totalDaysGoalMet >= 1)
    /// - App opened 3+ times
    /// - 3+ day streak
    func shouldShowPermissionPrompt() -> Bool {
        // Never show if already authorized or denied
        guard authorizationStatus == .notDetermined else { return false }

        // Never show if prompt was already shown and user completed it
        guard !hasShownPrompt else {
            // Exception: Check for 30-day re-prompt
            if dismissedDateTimestamp > 0 {
                let dismissedDate = Date(timeIntervalSince1970: dismissedDateTimestamp)
                let daysSinceDismiss = Calendar.current.dateComponents([.day], from: dismissedDate, to: Date()).day ?? 0
                if daysSinceDismiss >= 30 {
                    return true // Allow re-prompt after 30 days
                }
            }
            return false
        }

        // Check 30-day cooldown if previously dismissed
        if dismissedDateTimestamp > 0 {
            let dismissedDate = Date(timeIntervalSince1970: dismissedDateTimestamp)
            let daysSinceDismiss = Calendar.current.dateComponents([.day], from: dismissedDate, to: Date()).day ?? 0
            if daysSinceDismiss < 30 {
                return false // Still in cooldown period
            }
        }

        // Smart triggers - any one of these will trigger the prompt:
        let streakService = StreakService.shared
        let appLaunchCount = UserDefaults.standard.integer(forKey: "appLaunchCount")

        // 1. First goal completed
        if streakService.totalDaysGoalMet >= 1 {
            return true
        }

        // 2. App opened 3+ times
        if appLaunchCount >= 3 {
            return true
        }

        // 3. 3+ day streak
        if streakService.currentStreak >= 3 {
            return true
        }

        return false
    }

    // MARK: - Permission Request

    /// Request notification permission from the system
    /// Returns true if permission was granted
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            // Update status after request
            await checkAuthorizationStatus()

            if granted {
                // Register notification categories
                IWTService.registerNotificationCategories()
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }

            // Mark prompt as shown
            hasShownPrompt = true

            return granted
        } catch {
            print("❌ Failed to request notification permission: \(error)")
            hasShownPrompt = true
            return false
        }
    }

    // MARK: - Prompt Dismissal

    /// Mark the prompt as dismissed (user tapped "Not Now")
    func markPromptDismissed() {
        dismissedDateTimestamp = Date().timeIntervalSince1970
        hasShownPrompt = true
    }

    /// Mark the 30-day re-prompt banner as dismissed
    func markBannerDismissed() {
        bannerDismissed = true
    }

    /// Reset banner dismissed state (for testing or when re-prompt is triggered)
    func resetBannerDismissed() {
        bannerDismissed = false
    }
}
