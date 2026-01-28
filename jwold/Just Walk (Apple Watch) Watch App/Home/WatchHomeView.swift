//
//  WatchHomeView.swift
//  Just Walk Watch App
//
//  Home screen with progress bar and walk button.
//

import SwiftUI
import WatchKit

struct WatchHomeView: View {
    @ObservedObject private var healthManager = WatchHealthManager.shared
    @ObservedObject private var sessionManager = WatchSessionManager.shared

    @State private var showCountdown = false
    @State private var showModePicker = false
    @State private var pendingWalkMode: WalkMode = .classic

    // Celebration tracking
    @AppStorage("lastCelebrationDate") private var lastCelebrationDate: Double = 0
    @State private var showConfetti = false

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 16 // Account for horizontal padding
            let ringSize = min(availableWidth * 0.75, 120) // 75% of width, max 120pt

            ZStack {
                ScrollView {
                    VStack(spacing: 12) {
                        // Permission denied banner
                        if !healthManager.isAuthorized {
                            deniedPermissionsBanner
                        }

                        // Centered progress ring - now responsive
                        HomeProgressRing(
                            currentSteps: healthManager.todaySteps,
                            goal: healthManager.stepGoal,
                            todayDistance: healthManager.todayDistance,
                            onTap: {
                                if healthManager.todaySteps >= healthManager.stepGoal {
                                    triggerCelebration()
                                }
                            }
                        )
                        .frame(width: ringSize, height: ringSize)
                        .padding(.top, 8)

                        // Single walk button
                        justWalkButton
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }

                // Confetti overlay
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
        }
        .fullScreenCover(isPresented: $showCountdown) {
            WatchCountdownView(
                walkMode: pendingWalkMode,
                onComplete: startWalk,
                onCancel: { showCountdown = false }
            )
        }
        .sheet(isPresented: $showModePicker) {
            WatchModePickerView(
                sessionManager: sessionManager,
                onStartOpenWalk: {
                    sessionManager.currentGoal = .none
                    pendingWalkMode = .classic
                    showModePicker = false
                    // Delay to let sheet fully dismiss before showing countdown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCountdown = true
                    }
                },
                onStartWithGoal: { goal in
                    sessionManager.currentGoal = goal
                    pendingWalkMode = .classic
                    showModePicker = false
                    // Delay to let sheet fully dismiss before showing countdown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCountdown = true
                    }
                },
                onStartInterval: {
                    sessionManager.currentGoal = .none
                    pendingWalkMode = .interval
                    showModePicker = false
                    // Delay to let sheet fully dismiss before showing countdown
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCountdown = true
                    }
                }
            )
        }
        .onAppear { checkForCelebration() }
        .onChange(of: healthManager.todaySteps) { _, _ in checkForCelebration() }
    }

    // MARK: - Just Walk Button

    private var justWalkButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            showModePicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14, weight: .semibold))
                Text("Just Walk")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "00C7BE"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Denied Permissions Banner

    /// Banner shown when HealthKit permissions are denied
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

    // MARK: - Actions

    private func startWalk() {
        showCountdown = false
        sessionManager.startSession(mode: pendingWalkMode, goal: sessionManager.currentGoal)
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
}

// MARK: - Preview

#Preview {
    WatchHomeView()
}
