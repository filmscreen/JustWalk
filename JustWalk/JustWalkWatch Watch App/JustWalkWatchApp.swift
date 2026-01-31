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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await WatchHealthKitManager.shared.requestAuthorizationAndFetch()
                    if WatchHealthKitManager.shared.isAuthorized {
                        WatchHealthKitManager.shared.setupStepObserver()
                    }
                }
        }
    }
}
