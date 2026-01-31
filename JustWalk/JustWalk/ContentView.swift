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
    @Environment(\.openURL) private var openURL
    @StateObject private var walkSession = WalkSessionManager.shared

    @State private var pendingMilestone: MilestoneEvent?
    @State private var pendingMoment: EmotionalMoment?
    @State private var showLiveActivityPrompt = false
    @State private var liveActivityPromptMode: WalkMode?
    @State private var didAppear = false

    /// Whether the active walk banner should be visible
    private var shouldShowActiveWalkBanner: Bool {
        walkSession.isWalking && !appState.isViewingActiveWalk
    }

    var body: some View {
        @Bindable var appState = appState

        ZStack(alignment: .top) {
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

                        Tab("Eat", systemImage: "fork.knife", value: .eat) {
                            NavigationStack {
                                EatTabView()
                            }
                        }

                        Tab("Settings", systemImage: "gearshape", value: .settings) {
                            NavigationStack {
                                SettingsView()
                            }
                        }
                    }
                } else {
                    TabView(selection: $appState.selectedTab) {
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
                            EatTabView()
                        }
                        .tabItem { Label("Eat", systemImage: "fork.knife") }
                        .tag(AppTab.eat)

                        NavigationStack {
                            SettingsView()
                        }
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(AppTab.settings)
                    }
                }
            }

            // Active Walk Banner - shown when walk is active and user is not on walk screen
            if shouldShowActiveWalkBanner {
                ActiveWalkBanner {
                    returnToActiveWalk()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: shouldShowActiveWalkBanner)
        .tint(JW.Color.accent)
        .toolbarBackground(JW.Color.backgroundPrimary, for: .tabBar)
        .toastOverlay()
        .fullScreenCover(item: $pendingMilestone) { event in
            MilestoneFullscreenView(event: event) {
                pendingMilestone = nil
            }
        }
        .fullScreenCover(item: $pendingMoment) { moment in
            MomentView(moment: moment) {
                pendingMoment = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .emotionalMomentTriggered)) { notification in
            if let moment = notification.userInfo?["moment"] as? EmotionalMoment {
                // Don't interrupt if a milestone is already showing
                if pendingMilestone == nil {
                    pendingMoment = moment
                }
            }
        }
        .onAppear {
            didAppear = true
            checkForPendingFullscreen()
            consumePendingNotificationActionIfNeeded()
        }
        .onChange(of: appState.selectedTab) { _, _ in
            guard didAppear else { return }
            JustWalkHaptics.selectionChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: LiveActivityManager.promptNotification)) { notification in
            if let modeRaw = notification.userInfo?[LiveActivityManager.promptModeKey] as? String {
                liveActivityPromptMode = WalkMode(rawValue: modeRaw)
            } else {
                liveActivityPromptMode = nil
            }
            showLiveActivityPrompt = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .walkNotificationAction)) { notification in
            if let raw = notification.userInfo?["action"] as? String,
               let action = CardAction.fromRawValue(raw) {
                applyNotificationAction(action)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkForPendingFullscreen()
                consumePendingNotificationActionIfNeeded()
            }
        }
        .alert("Enable Live Activity", isPresented: $showLiveActivityPrompt) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text(liveActivityPromptMessage)
        }
    }

    private func checkForPendingFullscreen() {
        if let event = MilestoneManager.shared.checkPendingFullscreen() {
            pendingMilestone = event
        }
    }

    private func consumePendingNotificationActionIfNeeded() {
        if let raw = UserDefaults.standard.string(forKey: WalkNotificationManager.pendingActionKey),
           let action = CardAction.fromRawValue(raw) {
            UserDefaults.standard.removeObject(forKey: WalkNotificationManager.pendingActionKey)
            applyNotificationAction(action)
        }
    }

    private func applyNotificationAction(_ action: CardAction) {
        appState.pendingCardAction = action
        appState.selectedTab = .walks
    }

    /// Navigate back to the active walk screen
    private func returnToActiveWalk() {
        // Switch to Walks tab - the navigation will handle showing the active walk
        // Based on walk mode, set the appropriate pending action
        switch walkSession.currentMode {
        case .interval:
            appState.pendingCardAction = .startIntervalWalk
        case .fatBurn:
            appState.pendingCardAction = .startFatBurnWalk
        case .postMeal:
            appState.pendingCardAction = .startPostMealWalk
        case .free:
            appState.pendingCardAction = .startIntervalWalk // Default to intervals view
        }
        appState.selectedTab = .walks
    }

    private var liveActivityPromptMessage: String {
        let modeLabel: String = {
            switch liveActivityPromptMode {
            case .interval: return "interval"
            case .fatBurn: return "fat burn"
            case .postMeal: return "post-meal"
            case .free: return "walk"
            case .none: return "walk"
            }
        }()
        return "See your \(modeLabel) timer on the Lock Screen and Dynamic Island."
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
