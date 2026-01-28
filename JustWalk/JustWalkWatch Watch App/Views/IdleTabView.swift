//
//  IdleTabView.swift
//  JustWalkWatch Watch App
//
//  Two-page horizontal idle screen: Today stats (left) + Walk Start (right)
//

import SwiftUI

struct IdleTabView: View {
    @EnvironmentObject var appState: WatchAppState

    var body: some View {
        TabView {
            // Page 1: Today (progress ring, streak, phone status)
            WatchTodayView()

            // Page 2: Walks (intervals, fat burn, post-meal)
            NavigationStack {
                WalksWatchView()
            }
        }
        .tabViewStyle(.page)
    }
}
