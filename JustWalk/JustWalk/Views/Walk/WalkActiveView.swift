//
//  WalkActiveView.swift
//  JustWalk
//
//  Active walk state — dispatches to IntervalActiveView or free walk layout
//

import SwiftUI

struct WalkActiveView: View {
    @StateObject private var walkSession = WalkSessionManager.shared
    @State private var showEndConfirmation = false

    var body: some View {
        switch walkSession.currentMode {
        case .interval:
            IntervalActiveView()
        case .free, .fatBurn, .postMeal:
            freeWalkBody
        }
    }

    // MARK: - Free Walk Layout

    private var freeWalkBody: some View {
        ZStack {
            // Gradient background (no map)
            JW.Color.heroGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top: minimized stats bar
                WalkStatsBar(
                    elapsedSeconds: walkSession.elapsedSeconds,
                    steps: walkSession.currentSteps,
                    distanceMeters: walkSession.currentDistance
                )
                .padding(.top, JW.Spacing.sm)

                Spacer()

                // Center: large elapsed time display
                VStack(spacing: 24) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(JW.Color.accent)

                    Text(formatDuration(walkSession.elapsedSeconds))
                        .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.default, value: walkSession.elapsedSeconds)
                }

                Spacer()

                // Bottom: controls
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
        .alert("End this walk?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                Task { await walkSession.endWalk() }
            }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(JW.Font.title3.bold().monospacedDigit())
            Text(label)
                .font(JW.Font.caption2)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }
}

#Preview {
    WalkActiveView()
}
