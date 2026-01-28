//
//  BackgroundTaskManager.swift
//  Just Walk
//
//  Created by Just Walk Team.
//
//  REFACTORED: Now delegates all step data operations to StepRepository.
//  This removes duplicate CMPedometer queries and ensures single source of truth.
//

import Foundation
import BackgroundTasks
import WidgetKit

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    // Background Task Identifier
    let refreshTaskIdentifier = "com.onworldtech.JustWalk.refresh"

    // Track last background refresh for logging
    private var lastBackgroundRefresh: Date = .distantPast

    private init() {}

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        // AGGRESSIVE: Request 1 minute interval (Apple will likely throttle to ~15 min minimum)
        // But by requesting 1 min, we signal high importance and get the fastest possible cadence
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Background refresh scheduled for ~1 min from now")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    func handleAppRefresh(task: BGAppRefreshTask) {
        let startTime = Date()
        print("🔄 Background refresh starting at \(startTime)")

        // Schedule the next refresh IMMEDIATELY to maintain aggressive cadence
        scheduleAppRefresh()

        // Expiration Handler
        task.expirationHandler = {
            print("⚠️ Background refresh expired")
        }

        // Perform Work - All data operations now go through StepRepository
        Task { @MainActor in
            // 1. Force refresh from all data sources via StepRepository
            //    This triggers: CMPedometer update + HealthKit query + App Group save + Widget refresh
            await StepRepository.shared.forceRefresh()

            // 2. HealthKit iCloud sync handles Watch automatically
            // No WatchConnectivity needed - devices are independent

            // 3. Smart Coach: Evaluate progress and schedule appropriate notifications
            NotificationIntelligenceManager.shared.scheduleSmartEveningUpdate()

            // Log timing
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Background refresh completed in \(String(format: "%.2f", duration))s - Steps: \(StepRepository.shared.todaySteps)")

            // 4. Complete Task
            task.setTaskCompleted(success: true)
        }
    }
}
