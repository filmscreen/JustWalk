//
//  WatchSummaryView.swift
//  Just Walk Watch App
//
//  Post-workout summary with route map, congratulatory message, and tile stats grid.
//

import SwiftUI
import WatchKit
import MapKit

struct WatchSummaryView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @ObservedObject private var healthManager = WatchHealthManager.shared

    @State private var showConfetti = false
    @State private var hasPlayedHaptic = false

    // Auto-dismiss timer
    @State private var autoDismissTimer: Timer?
    @State private var lastInteractionTime = Date()
    private let autoDismissInterval: TimeInterval = 60

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 1. Congratulatory Header
                headerSection

                // 3. Stats Grid (2x2)
                statsGrid

                // 4. Done Button
                doneButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .onAppear { handleAppear() }
        .onDisappear { autoDismissTimer?.invalidate() }
        // Swipe right to dismiss (standard watchOS back gesture)
        .gesture(swipeGesture)
        .overlay {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                resetAutoDismissTimer()
                if value.translation.width > 50 {
                    sessionManager.closeSummary()
                }
            }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 2) {
            Text(headerTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(headerColor)

            Text(headerSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var headerTitle: String {
        if goalCompletedThisWorkout {
            return "Goal Crushed!"
        } else if sessionManager.sessionSteps >= 2000 {
            return "Great Job!"
        } else if sessionManager.sessionSteps >= 500 {
            return "Nice Walk!"
        } else {
            return "Walk Complete"
        }
    }

    private var headerColor: Color {
        goalCompletedThisWorkout ? .yellow : Color(hex: "34C759")
    }

    private var headerSubtitle: String {
        let duration = formatDuration(sessionManager.finalDuration)
        return "You completed a \(duration) walk"
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(spacing: 8) {
            // Top row: Time | Steps
            HStack(spacing: 8) {
                statTile(
                    icon: "clock.fill",
                    value: formatDuration(sessionManager.finalDuration),
                    label: "Time",
                    color: .blue
                )
                statTile(
                    icon: "shoeprints.fill",
                    value: sessionManager.sessionSteps.formatted(),
                    label: "Steps",
                    color: .cyan
                )
            }

            // Bottom row: Distance | Calories
            HStack(spacing: 8) {
                statTile(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    value: formattedSessionDistance,
                    label: "Distance",
                    color: .teal
                )
                statTile(
                    icon: "flame.fill",
                    value: "\(Int(sessionManager.activeCalories))",
                    label: "Cal",
                    color: .orange
                )
            }
        }
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            resetAutoDismissTimer()
            WKInterfaceDevice.current().play(.click)
            sessionManager.closeSummary()
        } label: {
            Text("Done")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "00C7BE"))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Format session distance (sessionManager.distance is in miles)
    private var formattedSessionDistance: String {
        let unit = WatchDistanceUnit.preferred
        let distanceInMeters = sessionManager.distance * 1609.34  // Convert miles to meters
        let value = distanceInMeters * unit.conversionFromMeters
        return String(format: "%.2f %@", value, unit.abbreviation)
    }

    private var goalCompletedThisWorkout: Bool {
        !sessionManager.goalWasMetBeforeWorkout &&
        healthManager.todaySteps >= healthManager.stepGoal
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Lifecycle

    private func handleAppear() {
        // Play haptic patterns
        if !hasPlayedHaptic {
            hasPlayedHaptic = true
            playCompletionHaptics()
        }

        // Show confetti if goal completed this workout
        if goalCompletedThisWorkout {
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { showConfetti = false }
            }
        }

        // Start auto-dismiss timer
        startAutoDismissTimer()
    }

    private func playCompletionHaptics() {
        let device = WKInterfaceDevice.current()

        Task {
            if goalCompletedThisWorkout {
                // Goal celebration: Success + Victory pattern
                device.play(.success)
                try? await Task.sleep(nanoseconds: 150_000_000)

                for _ in 0..<3 {
                    device.play(.notification)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }

                try? await Task.sleep(nanoseconds: 150_000_000)
                device.play(.success)
            } else {
                // Workout complete (no goal): Double tap acknowledgment
                device.play(.success)
                try? await Task.sleep(nanoseconds: 200_000_000)
                device.play(.directionUp)
            }
        }
    }

    // MARK: - Auto-Dismiss

    private func startAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        lastInteractionTime = Date()

        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(lastInteractionTime)
            if elapsed >= autoDismissInterval {
                Task { @MainActor in
                    sessionManager.closeSummary()
                }
            }
        }
    }

    private func resetAutoDismissTimer() {
        lastInteractionTime = Date()
    }
}

// MARK: - Preview

#Preview {
    WatchSummaryView()
}
