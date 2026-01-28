//
//  WalkLandingViewV2.swift
//  Just Walk
//
//  Redesigned Walk tab with map background and bottom sheet cards.
//  Uses ZStack layout with live map (~45% screen) and fixed bottom cards.
//

import SwiftUI

struct WalkLandingViewV2: View {
    @StateObject private var viewModel = WalkLandingViewModel()
    @StateObject private var mapViewModel = WalkMapViewModel()
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var stepRepo = StepRepository.shared

    // Sheet states
    @State private var showCountdown = false
    @State private var countdownMode: WalkMode = .classic
    @State private var showPaywall = false
    @State private var selectedGoal: WalkGoal = .none
    @State private var intervalConfig: IWTConfiguration?
    @State private var activeRoute: RouteGenerator.GeneratedRoute?

    // Saved routes states
    @State private var showSavedRoutesSheet = false
    @State private var selectedSavedRoute: SavedRoute?

    // Interval picker state
    @State private var showIntervalPicker = false

    // Goal picker state
    @State private var showGoalPicker = false

    // Post-Meal states
    @State private var showPostMealSetup = false
    @State private var showPostMealCountdown = false
    @State private var showPostMealActive = false

    // Permission states
    @ObservedObject private var permissionGate = WalkPermissionGate.shared
    @State private var showPermissionSheet = false
    @State private var showLocationWarning = false

    var body: some View {
        ZStack {
            // Layer 1: Map or fallback (full screen)
            WalkMapBackgroundView(viewModel: mapViewModel)
                .ignoresSafeArea()

            // Layer 2: Bottom sheet (anchored to bottom)
            VStack {
                Spacer()
                WalkBottomSheet(
                    viewModel: viewModel,
                    onJustWalkTap: handleJustWalkTap,
                    onGoalWalkTap: handleGoalWalkTap,
                    onIntervalTap: handleIntervalTap,
                    onPostMealTap: handlePostMealTap,
                    onSavedRoutes: { showSavedRoutesSheet = true }
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .onAppear {
            viewModel.refresh()
        }
        .task {
            // Ensure StepRepository has fresh data when Walk tab appears
            await StepRepository.shared.forceRefresh()
            viewModel.refresh()
        }
        .onChange(of: stepRepo.todaySteps) { _, _ in
            viewModel.refresh()
        }
        .fullScreenCover(isPresented: $showCountdown) {
            PreWalkCountdownView(
                walkMode: countdownMode,
                walkGoal: selectedGoal,
                onComplete: startWalk,
                onCancel: { showCountdown = false }
            )
        }
        .fullScreenCover(isPresented: $showPaywall) {
            ProPaywallView {
                showPaywall = false
            }
        }
        .sheet(isPresented: $showPermissionSheet) {
            if let blocking = permissionGate.blockingPermission {
                PermissionRequiredSheet(
                    permission: blocking,
                    onDismiss: {
                        showPermissionSheet = false
                    },
                    onOpenSettings: {
                        showPermissionSheet = false
                        if blocking.opensHealth {
                            permissionGate.openHealthSettings()
                        } else {
                            permissionGate.openAppSettings()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showLocationWarning) {
            LocationWarningSheet(
                onEnableLocation: {
                    showLocationWarning = false
                    permissionGate.openAppSettings()
                },
                onContinueAnyway: {
                    permissionGate.markDismissed()
                    showLocationWarning = false
                    // Start walk directly with no goal
                    startWalkWithGoal(.none)
                }
            )
            .presentationDetents([.height(280)])
        }
        .fullScreenCover(item: $activeRoute) { route in
            RouteWalkSessionView(route: route)
        }
        .sheet(isPresented: $showSavedRoutesSheet) {
            SavedRoutesSheet(
                onSelectRoute: { route in
                    showSavedRoutesSheet = false
                    selectedSavedRoute = route
                },
                onGenerateFirst: {
                    // Route generation is now accessed through GoalPickerSheet
                    showSavedRoutesSheet = false
                    showGoalPicker = true
                },
                onShowPaywall: {
                    showSavedRoutesSheet = false
                    showPaywall = true
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedSavedRoute) { route in
            SavedRouteDetailView(route: route) { generatedRoute in
                selectedSavedRoute = nil
                activeRoute = generatedRoute
            }
        }
        .sheet(isPresented: $showGoalPicker) {
            GoalPickerSheet(
                onStartWalk: { goal in
                    // Save goal if selected
                    UserDefaults.standard.lastWalkGoal = goal
                    startWalkWithGoal(goal)
                },
                onStartWithRoute: { goal, route in
                    // Save goal and start with route
                    UserDefaults.standard.lastWalkGoal = goal
                    selectedGoal = goal
                    activeRoute = route
                },
                onDismiss: {
                    showGoalPicker = false
                },
                onShowPaywall: {
                    showGoalPicker = false
                    showPaywall = true
                }
            )
        }
        .sheet(isPresented: $showIntervalPicker) {
            IntervalPickerSheet(
                onStartInterval: { config in
                    showIntervalPicker = false
                    intervalConfig = config
                    countdownMode = .interval
                    showCountdown = true
                },
                onDismiss: {
                    showIntervalPicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPostMealSetup) {
            PostMealSetupView(
                onStartWalk: {
                    showPostMealSetup = false
                    // Brief delay to let sheet dismiss before showing countdown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPostMealCountdown = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showPostMealCountdown) {
            PreWalkCountdownView(
                walkMode: .postMeal,
                onComplete: {
                    showPostMealCountdown = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showPostMealActive = true
                    }
                },
                onCancel: { showPostMealCountdown = false }
            )
        }
        .fullScreenCover(isPresented: $showPostMealActive) {
            PostMealActiveView()
        }
    }

    // MARK: - Actions

    private func handleJustWalkTap() {
        HapticService.shared.playSelection()

        Task {
            let canStart = await permissionGate.checkPermissions()

            if !canStart {
                // Show blocking permission sheet
                showPermissionSheet = true
            } else if permissionGate.shouldShowLocationWarning {
                // Show location warning (can continue)
                showLocationWarning = true
            } else {
                // All good - start walk immediately with no goal
                startWalkWithGoal(.none)
            }
        }
    }

    private func handleIntervalTap() {
        HapticService.shared.playSelection()

        Task {
            let canStart = await permissionGate.checkPermissions()

            if !canStart {
                showPermissionSheet = true
            } else if permissionGate.shouldShowLocationWarning {
                showLocationWarning = true
            } else if subscriptionManager.isPro {
                // Pro user - show interval picker
                showIntervalPicker = true
            } else {
                // Free user - show paywall
                showPaywall = true
            }
        }
    }

    private func handlePostMealTap() {
        HapticService.shared.playSelection()

        Task {
            let canStart = await permissionGate.checkPermissions()

            if !canStart {
                showPermissionSheet = true
            } else if permissionGate.shouldShowLocationWarning {
                showLocationWarning = true
            } else {
                showPostMealSetup = true
            }
        }
    }

    private func handleGoalWalkTap() {
        HapticService.shared.playSelection()

        Task {
            let canStart = await permissionGate.checkPermissions()

            if !canStart {
                // Show blocking permission sheet
                showPermissionSheet = true
            } else if permissionGate.shouldShowLocationWarning {
                // Show location warning (can continue)
                showLocationWarning = true
            } else {
                // All good - show goal picker
                showGoalPicker = true
            }
        }
    }

    private func startWalkWithGoal(_ goal: WalkGoal) {
        selectedGoal = goal
        countdownMode = .classic
        showCountdown = true
    }

    private func startWalk() {
        showCountdown = false

        // Configure IWTService based on walk mode
        let service = IWTService.shared
        service.sessionMode = countdownMode

        // Configure for interval mode
        if countdownMode == .interval, let config = intervalConfig {
            service.configuration = config
            service.currentPhase = .slow
        } else {
            service.currentPhase = countdownMode == .interval ? .warmup : .classic
        }

        // Post notification to trigger session view, including the walk goal
        NotificationCenter.default.post(
            name: .remoteSessionStarted,
            object: nil,
            userInfo: ["mode": countdownMode, "walkGoal": selectedGoal]
        )

        intervalConfig = nil  // Clear after use
    }
}

// MARK: - Preview

#Preview {
    WalkLandingViewV2()
}
