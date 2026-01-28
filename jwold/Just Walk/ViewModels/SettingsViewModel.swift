//
//  SettingsViewModel.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftUI
import CoreMotion
import Combine
import WidgetKit
import UserNotifications

/// ViewModel for settings management
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var dailyStepGoal: Int = 10000
    @Published var enableHaptics: Bool = true
    @Published var enableSoundCues: Bool = true
    @Published var enableCoachingTips: Bool = true
    @Published var iwtBriskMinutes: Int = 3
    @Published var iwtSlowMinutes: Int = 3
    @Published var iwtEnableWarmup: Bool = true
    @Published var iwtEnableCooldown: Bool = true

    @Published var motionAuthorized: Bool = false
    @Published var healthKitAuthorized: Bool = false
    @Published var healthKitDenied: Bool = false

    // Notification Preferences
    @Published var notificationsAuthorized: Bool = false
    @Published var notifStreakAtRisk: Bool = true
    @Published var notifGoalCelebrations: Bool = true
    @Published var notifMilestones: Bool = true
    @Published var notifStreakLost: Bool = true

    private let healthKitService = HealthKitService.shared

    // MARK: - Computed Properties

    /// Available step goals in 500-step increments
    var stepGoalOptions: [Int] {
        stride(from: 1000, through: 20000, by: 500).map { $0 }
    }

    /// IWT interval options in minutes
    var intervalOptions: [Int] {
        [1, 2, 3, 4, 5]
    }

    var formattedGoal: String {
        "\(dailyStepGoal.formatted()) steps"
    }

    var goalIncrements: Int {
        dailyStepGoal / 500
    }

    // MARK: - Initialization

    init() {
        loadSettings()
        loadNotificationPreferences()
        checkAuthorization()
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        let defaults = UserDefaults.standard

        dailyStepGoal = defaults.integer(forKey: "dailyStepGoal")
        if dailyStepGoal == 0 { dailyStepGoal = 10000 }

        enableHaptics = defaults.object(forKey: "enableHaptics") as? Bool ?? true
        enableSoundCues = defaults.object(forKey: "enableSoundCues") as? Bool ?? true
        enableCoachingTips = defaults.object(forKey: "enableCoachingTips") as? Bool ?? true

        iwtBriskMinutes = defaults.integer(forKey: "iwtBriskMinutes")
        if iwtBriskMinutes == 0 { iwtBriskMinutes = 3 }

        iwtSlowMinutes = defaults.integer(forKey: "iwtSlowMinutes")
        if iwtSlowMinutes == 0 { iwtSlowMinutes = 3 }
        
        iwtEnableWarmup = defaults.object(forKey: "iwtEnableWarmup") as? Bool ?? true
        iwtEnableCooldown = defaults.object(forKey: "iwtEnableCooldown") as? Bool ?? true
    }

    private func loadNotificationPreferences() {
        let defaults = UserDefaults.standard

        notifStreakAtRisk = defaults.object(forKey: "notif.streakAtRisk.enabled") as? Bool ?? true
        notifGoalCelebrations = defaults.object(forKey: "notif.goalCelebrations.enabled") as? Bool ?? true
        notifMilestones = defaults.object(forKey: "notif.milestones.enabled") as? Bool ?? true
        notifStreakLost = defaults.object(forKey: "notif.streakLost.enabled") as? Bool ?? true
    }

    func saveNotificationPreferences() {
        let defaults = UserDefaults.standard

        defaults.set(notifStreakAtRisk, forKey: "notif.streakAtRisk.enabled")
        defaults.set(notifGoalCelebrations, forKey: "notif.goalCelebrations.enabled")
        defaults.set(notifMilestones, forKey: "notif.milestones.enabled")
        defaults.set(notifStreakLost, forKey: "notif.streakLost.enabled")
    }

    func saveSettings() {
        let defaults = UserDefaults.standard

        defaults.set(dailyStepGoal, forKey: "dailyStepGoal")
        defaults.set(enableHaptics, forKey: "enableHaptics")
        defaults.set(enableSoundCues, forKey: "enableSoundCues")
        defaults.set(enableCoachingTips, forKey: "enableCoachingTips")
        defaults.set(iwtBriskMinutes, forKey: "iwtBriskMinutes")
        defaults.set(iwtSlowMinutes, forKey: "iwtSlowMinutes")
        defaults.set(iwtEnableWarmup, forKey: "iwtEnableWarmup")
        defaults.set(iwtEnableCooldown, forKey: "iwtEnableCooldown")
    }

    // MARK: - Goal Management

    func incrementGoal() {
        let newGoal = dailyStepGoal + 500
        if newGoal <= 50000 {
            dailyStepGoal = newGoal
            saveSettings()
            // Sync to StepRepository (triggers recalculation + notification)
            StepRepository.shared.stepGoal = dailyStepGoal
        }
    }

    func decrementGoal() {
        let newGoal = dailyStepGoal - 500
        if newGoal >= 500 {
            dailyStepGoal = newGoal
            saveSettings()
            // Sync to StepRepository (triggers recalculation + notification)
            StepRepository.shared.stepGoal = dailyStepGoal
        }
    }

    func setGoal(_ goal: Int) {
        dailyStepGoal = max(500, min(50000, (goal / 500) * 500))
        saveSettings()
        // Sync to StepRepository (triggers recalculation + notification)
        StepRepository.shared.stepGoal = dailyStepGoal
    }

    // MARK: - Authorization

    func checkAuthorization() {
        motionAuthorized = CMPedometer.authorizationStatus() == .authorized
        healthKitService.updateAuthorizationStatus()
        healthKitAuthorized = healthKitService.isAuthorized
        healthKitDenied = healthKitService.isHealthKitDenied

        // Check notification authorization
        Task {
            await checkNotificationAuthorization()
        }
    }

    func checkNotificationAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationsAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        }
    }

    func requestHealthKitPermission() async {
        guard HealthKitService.isHealthDataAvailable else { return }

        do {
            try await healthKitService.requestAuthorization()
            healthKitAuthorized = true
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }

    // MARK: - IWT Settings

    func updateBriskDuration(_ minutes: Int) {
        iwtBriskMinutes = minutes
        saveSettings()
    }

    func updateSlowDuration(_ minutes: Int) {
        iwtSlowMinutes = minutes
        saveSettings()
    }

    /// Get IWT configuration based on current settings
    func getIWTConfiguration() -> IWTConfiguration {
        IWTConfiguration(
            briskDuration: TimeInterval(iwtBriskMinutes * 60),
            slowDuration: TimeInterval(iwtSlowMinutes * 60),
            warmupDuration: 120,
            cooldownDuration: 120,
            totalIntervals: 5,
            enableWarmup: iwtEnableWarmup,
            enableCooldown: iwtEnableCooldown
        )
    }

    // MARK: - Toggle Handlers

    func toggleHaptics() {
        enableHaptics.toggle()
        saveSettings()
    }

    func toggleSoundCues() {
        enableSoundCues.toggle()
        saveSettings()
    }

    func toggleCoachingTips() {
        enableCoachingTips.toggle()
        saveSettings()
    }

    // MARK: - Debugging

    func addStepsToday() {
        let steps = 12000
        StepTrackingService.shared.simulateHistory(steps: steps, for: Date())
        NotificationCenter.default.post(name: .debugHistoryUpdated, object: nil)

        // Also update streak if goal reached (assumes 10k goal)
        if steps >= dailyStepGoal {
            StreakService.shared.debugMarkGoalReached(for: Date())
        }
        print("Debug: Added 12k steps to Today + streak update")
    }

    func setStepsToday6500() {
        StepTrackingService.shared.simulateHistory(steps: 6500, for: Date())
        NotificationCenter.default.post(name: .debugHistoryUpdated, object: nil)
        print("Debug: Set 6.5k steps to Today (no streak - below goal)")
    }

    func addStepsYesterday() {
        let steps = 12000
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
            StepTrackingService.shared.simulateHistory(steps: steps, for: yesterday)

            // Also update streak if goal reached
            if steps >= dailyStepGoal {
                StreakService.shared.debugMarkGoalReached(for: yesterday)
            }
        }
        NotificationCenter.default.post(name: .debugHistoryUpdated, object: nil)
        print("Debug: Added 12k steps to Yesterday + streak update")
    }
}
