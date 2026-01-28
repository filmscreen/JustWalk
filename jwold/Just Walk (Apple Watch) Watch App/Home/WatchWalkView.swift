//
//  WatchWalkView.swift
//  Just Walk Watch App
//
//  Main walk tab with vertical scrolling list and large touch targets.
//  Replaces WatchHomeView with simplified navigation flow.
//

import SwiftUI
import WatchKit

struct WatchWalkView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @ObservedObject private var healthManager = WatchHealthManager.shared

    @State private var showGoalPicker = false
    @State private var showCountdown = false
    @State private var pendingGoal: WalkGoal = .none
    @State private var showPostMealSetup = false

    // Celebration tracking
    @AppStorage("lastCelebrationDate") private var lastCelebrationDate: Double = 0
    @State private var showConfetti = false

    private var stepsToGo: Int {
        max(0, healthManager.stepGoal - healthManager.todaySteps)
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Permission denied banner
                    if !healthManager.isAuthorized {
                        deniedPermissionsBanner
                    }

                    // Header: Steps remaining
                    WalkHeaderView(stepsToGo: stepsToGo)

                    // Primary: Just Walk button (60pt, teal)
                    WalkActionButton(
                        icon: "figure.walk",
                        title: "Just Walk",
                        style: .primary
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        startJustWalk()
                    }

                    // Post-Meal Walk (55pt, orange tinted)
                    WalkActionButton(
                        icon: "fork.knife",
                        title: "Post-Meal",
                        style: .secondary
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        showPostMealSetup = true
                    }

                    // Secondary: With Goal (55pt, gray)
                    WalkActionButton(
                        icon: "timer",
                        title: "With Goal",
                        style: .secondary
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        showGoalPicker = true
                    }

                    // Pro: Interval (55pt, gray + PRO badge)
                    WalkActionButton(
                        icon: "bolt.fill",
                        title: "Interval",
                        style: .secondary,
                        isPro: !sessionManager.isPro
                    ) {
                        WKInterfaceDevice.current().play(.click)
                        startIntervalWalk()
                    }
                }
                .padding(.horizontal)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showPostMealSetup) {
            PostMealWatchSetupView()
        }
        .sheet(isPresented: $showGoalPicker) {
            WatchGoalPickerSheet(
                onSelectGoal: { goal in
                    showGoalPicker = false
                    pendingGoal = goal
                    sessionManager.currentGoal = goal
                    // Delay to let sheet fully dismiss before showing countdown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCountdown = true
                    }
                },
                onCancel: {
                    showGoalPicker = false
                }
            )
        }
        .fullScreenCover(isPresented: $showCountdown) {
            WatchCountdownView(
                walkMode: .classic,
                onComplete: {
                    showCountdown = false
                    sessionManager.startSession(mode: .classic, goal: pendingGoal)
                },
                onCancel: {
                    showCountdown = false
                }
            )
        }
        .onAppear { checkForCelebration() }
        .onChange(of: healthManager.todaySteps) { _, _ in checkForCelebration() }
    }

    // MARK: - Actions

    private func startJustWalk() {
        pendingGoal = .none
        sessionManager.currentGoal = .none
        showCountdown = true
    }

    private func startIntervalWalk() {
        if sessionManager.isPro {
            pendingGoal = .none
            sessionManager.currentGoal = .none
            showCountdown = true
        } else {
            // Show Pro upgrade prompt via haptic
            WKInterfaceDevice.current().play(.failure)
        }
    }

    // MARK: - Celebration

    private func checkForCelebration() {
        if healthManager.todaySteps >= healthManager.stepGoal {
            let lastDate = Date(timeIntervalSince1970: lastCelebrationDate)
            if !Calendar.current.isDateInToday(lastDate) {
                lastCelebrationDate = Date().timeIntervalSince1970
                triggerCelebration()
            }
        }
    }

    private func triggerCelebration() {
        showConfetti = false
        DispatchQueue.main.async { showConfetti = true }
        WKInterfaceDevice.current().play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showConfetti = false }
        }
    }

    // MARK: - Denied Permissions Banner

    private var deniedPermissionsBanner: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.orange)

            Text("Enable Health")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("Open Watch app on\niPhone to enable")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    WatchWalkView()
}
