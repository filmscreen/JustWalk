//
//  JustWalkSessionView.swift
//  Just Walk Watch App
//
//  During-workout screen for Just Walk (classic) mode.
//  Large primary metric centered, stats row below, minimal controls.
//  Supports Always-On Display with simplified view.
//

import SwiftUI
import WatchKit

struct JustWalkSessionView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @ObservedObject private var healthManager = WatchHealthManager.shared
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var showEndConfirmation = false
    @State private var showSecondaryStats = false

    var body: some View {
        // TimelineView for efficient Always-On updates
        TimelineView(.periodic(from: Date(), by: isLuminanceReduced ? 10 : 1)) { _ in
            if isLuminanceReduced {
                alwaysOnView
            } else if sessionManager.isPaused {
                JustWalkPausedView()
            } else {
                activeWorkoutView
            }
        }
    }

    // MARK: - Active Workout View

    private var activeWorkoutView: some View {
        VStack(spacing: 12) {
            // Goal badge (if active goal)
            if sessionManager.currentGoal.type != .none {
                goalBadge
            }

            Spacer()

            // Primary metric (large, centered)
            primaryMetricView

            // Goal progress bar (if active goal)
            if sessionManager.currentGoal.type != .none {
                GoalProgressBar(progress: sessionManager.goalProgress)
                    .padding(.horizontal, 4)
            }

            // Stats Row (HR, Calories, Duration)
            statsRow

            Spacer()

            // Control Buttons (side-by-side rectangular)
            controlButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .sheet(isPresented: $showSecondaryStats) {
            JustWalkSecondaryStatsView()
        }
        .confirmationDialog("End walk?", isPresented: $showEndConfirmation) {
            Button("End Walk", role: .destructive) {
                sessionManager.stopSession()
            }
            Button("Keep Walking", role: .cancel) {}
        }
        // Digital Crown to show secondary stats
        .focusable()
        .digitalCrownRotation(
            Binding(get: { 0.0 }, set: { value in
                if abs(value) > 0.3 && !showSecondaryStats {
                    showSecondaryStats = true
                }
            }),
            from: -1, through: 1
        )
    }

    // MARK: - Primary Metric View

    @ViewBuilder
    private var primaryMetricView: some View {
        VStack(spacing: 4) {
            switch sessionManager.currentGoal.type {
            case .none:
                // Classic walk - show session steps
                Text("\(sessionManager.sessionSteps.formatted())")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("steps")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

            case .time:
                // Time goal - show remaining time
                let target = sessionManager.currentGoal.target * 60
                let elapsed = sessionManager.sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
                let remaining = max(0, target - elapsed)
                Text(formatTimeRemaining(remaining))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("remaining")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

            case .distance:
                // Distance goal - show distance covered
                let unit = WatchDistanceUnit.preferred
                let distanceInMeters = sessionManager.distance * 1609.34
                let currentValue = distanceInMeters * unit.conversionFromMeters
                let goalInMeters = sessionManager.currentGoal.target * 1609.34
                let goalValue = goalInMeters * unit.conversionFromMeters
                Text(String(format: "%.2f", currentValue))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("of \(String(format: "%.1f", goalValue)) \(unit.abbreviation)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

            case .steps:
                // Steps goal - show progress
                Text("\(sessionManager.sessionSteps.formatted())")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("of \(Int(sessionManager.currentGoal.target).formatted())")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
    }

    // MARK: - Goal Badge

    private var goalBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: sessionManager.currentGoal.type.icon)
                .font(.system(size: 12))
            Text(sessionManager.currentGoal.type.label)
                .font(.system(size: 12, weight: .medium))

            if sessionManager.isGoalReached {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            }
        }
        .foregroundStyle(.teal)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.teal.opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Format Time Remaining

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Heart Rate
            statItem(
                icon: "heart.fill",
                value: sessionManager.currentHeartRate > 0
                    ? "\(Int(sessionManager.currentHeartRate))"
                    : "--",
                color: .red
            )

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            // Calories
            statItem(
                icon: "flame.fill",
                value: sessionManager.activeCalories > 0
                    ? "\(Int(sessionManager.activeCalories))"
                    : "--",
                color: .orange
            )

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            // Duration
            if let startTime = sessionManager.sessionStartTime {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text(startTime, style: .timer)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statItem(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 8) {
            // Pause Button
            Button {
                WKInterfaceDevice.current().play(.click)
                sessionManager.pauseSession()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pause")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // End Button
            Button {
                WKInterfaceDevice.current().play(.click)
                handleEndTap()
            } label: {
                Text("End")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func handleEndTap() {
        // Smart confirmation: only for significant walks
        let hasSignificantSteps = sessionManager.sessionSteps >= 500
        let hasSignificantTime = sessionManager.sessionStartTime.map {
            Date().timeIntervalSince($0) >= 300 // 5 minutes
        } ?? false

        if hasSignificantSteps || hasSignificantTime {
            showEndConfirmation = true
        } else {
            // End immediately for short walks
            sessionManager.stopSession()
        }
    }

    // MARK: - Always-On Display View

    /// Simplified view for Always-On Display (wrist down)
    /// Shows only essential info: steps + time
    /// Updates every 10 seconds to save battery
    private var alwaysOnView: some View {
        VStack(spacing: 12) {
            Spacer()

            // Steps (large, dimmed)
            VStack(spacing: 2) {
                Text("\(sessionManager.sessionSteps.formatted())")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText())
                    .monospacedDigit()

                Text("steps")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Time (smaller, dimmed)
            if let startTime = sessionManager.sessionStartTime {
                Text(startTime, style: .timer)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }

            Spacer()
        }
    }
}

// MARK: - Goal Progress Bar

struct GoalProgressBar: View {
    let progress: Double

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)

                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        progress >= 1.0
                            ? LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.teal, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geometry.size.width * clampedProgress, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: clampedProgress)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#Preview("Active") {
    JustWalkSessionView()
}

#Preview("Always-On") {
    JustWalkSessionView()
        .environment(\.isLuminanceReduced, true)
}

#Preview("Progress Bar") {
    VStack(spacing: 20) {
        GoalProgressBar(progress: 0.25)
        GoalProgressBar(progress: 0.5)
        GoalProgressBar(progress: 0.75)
        GoalProgressBar(progress: 1.0)
    }
    .padding()
}
