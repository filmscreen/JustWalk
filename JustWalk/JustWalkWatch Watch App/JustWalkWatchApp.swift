//
//  JustWalkWatchApp.swift
//  JustWalkWatch Watch App
//
//  Created by Randy Chia on 1/23/26.
//

import SwiftUI

@main
struct JustWalkWatch_Watch_AppApp: App {
    @StateObject private var appState = WatchAppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    // Cleanup any zombie workout sessions on app launch
                    // This handles cases where the app was terminated mid-workout
                    // or a session was left running due to a bug
                    cleanupZombieSessions()

                    await WatchHealthKitManager.shared.requestAuthorizationAndFetch()
                    if WatchHealthKitManager.shared.isAuthorized {
                        WatchHealthKitManager.shared.setupStepObserver()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    // MARK: - Zombie Session Cleanup

    /// Cleanup any zombie workout sessions that might be causing the persistent indicator.
    /// This runs on app launch to catch sessions that weren't properly ended.
    private func cleanupZombieSessions() {
        let walkSession = appState.walkSession

        // If WatchWorkoutManager has an active session but walkSession says no walk is active,
        // we have a zombie session that needs to be cleaned up
        if !walkSession.isWalking {
            WatchWorkoutManager.shared.forceCleanupIfNeeded()
        }
    }

    // MARK: - Scene Phase Handling

    /// Handle app lifecycle changes to ensure proper session cleanup
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active - check for zombie sessions
            // This catches cases where the app was backgrounded and a session ended abnormally
            if !appState.walkSession.isWalking {
                WatchWorkoutManager.shared.forceCleanupIfNeeded()
            }
            // Ensure timer is running if walk is active (system may have killed it while backgrounded)
            appState.walkSession.ensureTimerRunning()

        case .inactive:
            // App is about to become inactive (e.g., switching apps)
            // No cleanup needed yet - walk may still be in progress
            break

        case .background:
            // App moved to background
            // If no walk is in progress, ensure any stale sessions are cleaned up
            // This prevents the green indicator from persisting when the app is backgrounded
            if !appState.walkSession.isWalking && !appState.walkSession.isEnding {
                WatchWorkoutManager.shared.forceCleanup()
            }

        @unknown default:
            break
        }
    }
}
