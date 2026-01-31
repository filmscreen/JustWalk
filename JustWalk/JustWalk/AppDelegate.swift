//
//  AppDelegate.swift
//  JustWalk
//
//  Notification handling, deep links, and background task registration
//

import UIKit
import UserNotifications
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Register background tasks for widget refresh - must happen before app finishes launching
        BackgroundTaskManager.shared.registerBackgroundTasks()

        // Start significant location monitoring for free background updates
        BackgroundTaskManager.shared.startSignificantLocationMonitoring()

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("🔔 willPresent notification: \(notification.request.identifier) - title: \(notification.request.content.title)")
        WalkNotificationManager.shared.markNotificationDeliveredIfNeeded(notification.request.content.userInfo)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        WalkNotificationManager.shared.handleNotificationResponse(response.notification.request.content.userInfo)
        completionHandler()
    }

    // applicationShouldRequestHealthAuthorization intentionally removed.
}
