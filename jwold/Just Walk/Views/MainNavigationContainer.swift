//
//  MainNavigationContainer.swift
//  Just Walk
//
//  Main tab navigation with iOS standard tab bar.
//  iOS 26 automatically applies Liquid Glass styling when compiled with Xcode 26.
//

import SwiftUI

// MARK: - App Tab Enum

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Today"
    case walk = "Walk"
    case levelUp = "Progress"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .walk: return "figure.walk"
        case .levelUp: return "trophy"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .walk: return "figure.walk"
        case .levelUp: return "trophy.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Adaptive Navigation Container

struct AdaptiveNavigationContainer: View {
    @EnvironmentObject var storeManager: StoreManager
    @ObservedObject private var challengeManager = ChallengeManager.shared
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label(AppTab.home.rawValue, systemImage: selectedTab == .home ? AppTab.home.selectedIcon : AppTab.home.icon)
            }
            .tag(AppTab.home)

            // Walk (Map-forward design - no NavigationStack wrapper)
            WalkTab()
            .tabItem {
                Label(AppTab.walk.rawValue, systemImage: selectedTab == .walk ? AppTab.walk.selectedIcon : AppTab.walk.icon)
            }
            .tag(AppTab.walk)

            // Progress (Premium only)
            if !storeManager.ownsLifetime {
                NavigationStack {
                    ProgressTabView()
                }
                .tabItem {
                    Label(AppTab.levelUp.rawValue, systemImage: selectedTab == .levelUp ? AppTab.levelUp.selectedIcon : AppTab.levelUp.icon)
                }
                .tag(AppTab.levelUp)
            }

            // Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppTab.settings.rawValue, systemImage: selectedTab == .settings ? AppTab.settings.selectedIcon : AppTab.settings.icon)
            }
            .tag(AppTab.settings)
        }
        .tint(.primary)
        .onChange(of: selectedTab) { _, _ in
            HapticService.shared.playSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteSessionStarted)) { _ in
            selectedTab = .walk
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToProgressTab)) { _ in
            selectedTab = .levelUp
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToWalkTab)) { _ in
            selectedTab = .walk
        }
        .onOpenURL { url in
            if url.scheme == "justwalk" && url.host == "home" {
                selectedTab = .home
            }
        }
        .overlay {
            if challengeManager.showCompletionToast {
                ChallengeCompleteToast(
                    isPerfect: challengeManager.completedChallengeIsPerfect,
                    onDismiss: {
                        challengeManager.showCompletionToast = false
                    }
                )
                .zIndex(999)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AdaptiveNavigationContainer()
        .environmentObject(StoreManager.shared)
}
