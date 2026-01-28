//
//  ContentView.swift
//  JustWalk
//
//  Created by Randy Chia on 1/23/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var pendingMilestone: MilestoneEvent?

    var body: some View {
        @Bindable var appState = appState

        Group {
            if #available(iOS 18, *) {
                TabView(selection: $appState.selectedTab) {
                    Tab("Today", systemImage: "circle.circle", value: .today) {
                        NavigationStack {
                            if appState.healthKitDenied {
                                HealthAccessRequiredView()
                            } else {
                                TodayView()
                            }
                        }
                    }

                    Tab("Walks", systemImage: "figure.walk", value: .walks) {
                        NavigationStack {
                            if appState.healthKitDenied {
                                HealthAccessRequiredView()
                            } else {
                                WalksHomeView()
                            }
                        }
                    }

                    Tab("Settings", systemImage: "gearshape", value: .settings) {
                        NavigationStack {
                            SettingsView()
                        }
                    }
                }
            } else {
                TabView {
                    NavigationStack {
                        if appState.healthKitDenied {
                            HealthAccessRequiredView()
                        } else {
                            TodayView()
                        }
                    }
                    .tabItem { Label("Today", systemImage: "circle.circle") }
                    .tag(AppTab.today)

                    NavigationStack {
                        if appState.healthKitDenied {
                            HealthAccessRequiredView()
                        } else {
                            WalksHomeView()
                        }
                    }
                    .tabItem { Label("Walks", systemImage: "figure.walk") }
                    .tag(AppTab.walks)

                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
                }
            }
        }
        .tint(JW.Color.accent)
        .toolbarBackground(JW.Color.backgroundPrimary, for: .tabBar)
        .toastOverlay()
        .fullScreenCover(item: $pendingMilestone) { event in
            MilestoneFullscreenView(event: event) {
                pendingMilestone = nil
            }
        }
        .onAppear {
            checkForPendingFullscreen()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkForPendingFullscreen()
            }
        }
    }

    private func checkForPendingFullscreen() {
        if let event = MilestoneManager.shared.checkPendingFullscreen() {
            pendingMilestone = event
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
