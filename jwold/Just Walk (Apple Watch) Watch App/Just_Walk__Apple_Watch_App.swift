//
//  Just_Walk__Apple_Watch_App.swift
//  Just Walk (Apple Watch) Watch App
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI
import WidgetKit
import WatchKit

@main
struct Just_Walk__Apple_Watch__Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        // DEBUG: Triple-tap to reset onboarding (remove in production)
                        .onTapGesture(count: 3) {
                            print("⌚️ DEBUG: Resetting onboarding")
                            hasCompletedOnboarding = false
                        }
                } else {
                    WatchOnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .onAppear {
                print("⌚️ App launched - hasCompletedOnboarding: \(hasCompletedOnboarding)")
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                // Refresh Pro status from App Group (synced from iPhone)
                WatchSessionManager.shared.refreshProStatus()

                // Only run app refresh tasks if onboarding is complete
                guard hasCompletedOnboarding else { return }

                // AGGRESSIVE: Force complication update when app is opened
                // This uses the enhanced method with checkpoint saving
                Task { @MainActor in
                    // Small delay to let pedometer data settle
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                    WatchHealthManager.shared.forceComplicationUpdate()
                }
                // Schedule next background refresh
                scheduleBackgroundRefresh()
            }
        }
        .backgroundTask(.appRefresh("BGRefresh")) {
            await WatchSessionManager.shared.performBackgroundRefresh()
            await MainActor.run {
                // AGGRESSIVE: Force complication update after background refresh
                WatchHealthManager.shared.forceComplicationUpdate()
                scheduleBackgroundRefresh()
            }
        }
    }

    private func scheduleBackgroundRefresh() {
        // AGGRESSIVE: Schedule next refresh in 1 minute (60 seconds)
        // Apple will throttle to ~15 min minimum, but by requesting 1 min
        // we signal high importance and get the fastest possible cadence
        let nextRefresh = Date().addingTimeInterval(60)

        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextRefresh, userInfo: nil) { error in
            if let error = error {
                print("⚠️ Error scheduling background refresh: \(error.localizedDescription)")
            } else {
                print("📅 Watch: Background refresh scheduled for ~1 min from now")
            }
        }
    }
}
