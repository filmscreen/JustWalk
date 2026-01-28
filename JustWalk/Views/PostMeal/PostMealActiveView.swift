//
//  PostMealActiveView.swift
//  JustWalk
//
//  Active post-meal walk screen with a 10-minute countdown timer.
//  Simplest active walk — no phases, no pacing, just a timer.
//

import SwiftUI

struct PostMealActiveView: View {
    @StateObject private var walkSession = WalkSessionManager.shared

    @State private var showEndConfirmation = false
    @State private var countdownTimer: Timer?

    // 10 minutes in seconds
    private let totalDuration: Int = 600

    private var remainingSeconds: Int {
        max(0, totalDuration - walkSession.elapsedSeconds)
    }

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1.0, Double(walkSession.elapsedSeconds) / Double(totalDuration))
    }

    private var isComplete: Bool {
        remainingSeconds <= 0
    }

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Stats bar at top
                WalkStatsBar(
                    elapsedSeconds: walkSession.elapsedSeconds,
                    steps: walkSession.currentSteps,
                    distanceMeters: walkSession.currentDistance
                )
                .padding(.top, JW.Spacing.md)

                Spacer()

                // Hero countdown timer
                VStack(spacing: JW.Spacing.sm) {
                    Text(formatCountdown(remainingSeconds))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(JW.Color.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: remainingSeconds)

                    Text("remaining")
                        .font(JW.Font.title3)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()

                // Progress bar
                WalkProgressBar(
                    progress: progress,
                    tint: JW.Color.accentPurple,
                    showLabel: true
                )

                // Encouragement
                Text("Just keep walking.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .padding(.top, JW.Spacing.lg)

                Spacer()

                // Controls
                WalkControlBar(
                    isPaused: walkSession.isPaused,
                    onTogglePause: {
                        if walkSession.isPaused {
                            walkSession.resumeWalk()
                        } else {
                            walkSession.pauseWalk()
                        }
                    },
                    onEnd: {
                        showEndConfirmation = true
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("End this walk?", isPresented: $showEndConfirmation) {
            Button("End Walk", role: .destructive) {
                endWalk()
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Your progress still counts.")
        }
        .onAppear {
            startCompletionMonitor()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
        .onChange(of: walkSession.elapsedSeconds) { _, newValue in
            // Halfway chime at 5:00
            if newValue == totalDuration / 2 {
                JustWalkHaptics.progressMilestone()
            }
        }
    }

    // MARK: - Timer Monitoring

    private func startCompletionMonitor() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard walkSession.isWalking, !walkSession.isPaused else { return }

            if remainingSeconds <= 0 {
                countdownTimer?.invalidate()
                countdownTimer = nil
                completeWalk()
            }
        }
    }

    private func completeWalk() {
        JustWalkHaptics.walkComplete()

        Task {
            if let walk = await walkSession.endWalk() {
                walkSession.completedWalk = walk
            }
        }
    }

    private func endWalk() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        Task {
            if let walk = await walkSession.endWalk() {
                walkSession.completedWalk = walk
            }
        }
    }

    // MARK: - Formatting

    private func formatCountdown(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    PostMealActiveView()
}
