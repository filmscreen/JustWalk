//
//  ContentView.swift
//  JustWalkWatch Watch App
//
//  Root navigation: idle, active walk, or post-walk summary
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        switch appState.currentScreen {
        case .idle:
            IdleTabView()

        case .activeWalk:
            if appState.walkSession.isFatBurnMode {
                FatBurnActiveWatchView(
                    session: appState.walkSession,
                    onEnd: {
                        Task { await appState.endWalk() }
                    }
                )
            } else {
                WatchWalkActiveView(
                    session: appState.walkSession,
                    onEnd: {
                        Task { await appState.endWalk() }
                    }
                )
            }

        case .walkSummary(let record):
            WatchWalkSummaryView(record: record) {
                appState.dismissSummary()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchAppState())
}
