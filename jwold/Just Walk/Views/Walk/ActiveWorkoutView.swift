//
//  ActiveWorkoutView.swift
//  Just Walk
//
//  Unified active workout view with Metrics/Map toggle.
//  Replaces both IWTSessionView and PhoneWorkoutSessionView.
//

import SwiftUI
import MapKit
import HealthKit

enum ActiveWorkoutDisplayMode: String, CaseIterable {
    case metrics = "Metrics"
    case map = "Map"
}

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var workoutManager = PhoneWorkoutManager.shared
    @ObservedObject private var iwtService = IWTService.shared

    let mode: WalkMode

    @State private var displayMode: ActiveWorkoutDisplayMode = .metrics
    @State private var showingSummary = false
    @State private var completedWorkout: PhoneWorkoutSummary?
    @State private var showingCancelAlert = false
    @State private var startError: String?
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            // Main workout content - show immediately
            VStack(spacing: 0) {
                // Header with mode toggle
                headerSection
                    .padding(.top, 16)

                // Content based on display mode
                if displayMode == .metrics {
                    metricsContent
                } else {
                    mapContent
                }

                // Controls
                controlsSection
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .task {
            do {
                try await workoutManager.startWorkout()
                if mode == .interval {
                    iwtService.startSession(mode: mode)
                }
            } catch {
                startError = error.localizedDescription
            }
        }
        .alert("Cancel Workout?", isPresented: $showingCancelAlert) {
            Button("Continue", role: .cancel) { }
            Button("Discard", role: .destructive) {
                workoutManager.cancelWorkout()
                if mode == .interval {
                    _ = iwtService.endSession()
                }
                dismiss()
            }
        } message: {
            Text("Your workout will not be saved.")
        }
        .alert("Error", isPresented: .init(
            get: { startError != nil },
            set: { if !$0 { startError = nil; dismiss() } }
        )) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(startError ?? "Failed to start workout")
        }
        .sheet(isPresented: $showingSummary) {
            if let summary = completedWorkout, let workout = summary.workout {
                WorkoutSummaryView(workout: workout)
            }
        }
        .onChange(of: showingSummary) { _, isShowing in
            if !isShowing {
                dismiss()
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: mode == .interval ?
                [Color(red: 0.15, green: 0.05, blue: 0.20), Color(red: 0.08, green: 0.02, blue: 0.12)] :
                [Color(red: 0.05, green: 0.15, blue: 0.10), Color(red: 0.02, green: 0.08, blue: 0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title row with close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode == .interval ? "Interval Walk" : mode == .postMeal ? "Post-Meal Walk" : "Classic Walk")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    gpsStatusIndicator
                }

                Spacer()

                Button {
                    showingCancelAlert = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Display mode toggle
            displayModeToggle
        }
    }

    private var gpsStatusIndicator: some View {
        GPSStatusPill(isRecording: workoutManager.isRecordingRoute)
    }

    private var displayModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ActiveWorkoutDisplayMode.allCases, id: \.self) { toggleMode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayMode = toggleMode
                    }
                    HapticService.shared.playSelection()
                } label: {
                    Text(toggleMode.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(displayMode == toggleMode ? .black : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(displayMode == toggleMode ? .white : .clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Metrics Content

    private var metricsContent: some View {
        VStack(spacing: 24) {
            Spacer()

            // Large timer
            Text(formattedDuration)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            // Interval phase indicator
            if mode == .interval {
                intervalPhaseIndicator
            }

            // Pause indicator
            if workoutManager.state == .paused {
                Text("PAUSED")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.yellow.opacity(0.2))
                    .clipShape(Capsule())
            }

            Spacer()

            // Stats row
            statsRow
        }
    }

    private var intervalPhaseIndicator: some View {
        VStack(spacing: 8) {
            Text(iwtService.currentPhase.rawValue.uppercased())
                .font(.title3.bold())
                .foregroundStyle(iwtService.currentPhase == .brisk ? .orange : .cyan)

            // Phase progress ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: phaseProgress)
                    .stroke(
                        iwtService.currentPhase == .brisk ? Color.orange : Color.cyan,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text(formattedPhaseTime)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
        }
    }

    private var phaseProgress: Double {
        let elapsed = iwtService.phaseTimeRemaining
        let total = 180.0 // 3 minutes per phase
        return max(0, min(1, (total - elapsed) / total))
    }

    private var formattedPhaseTime: String {
        let remaining = Int(iwtService.phaseTimeRemaining)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(workoutManager.sessionSteps.formatted())",
                label: "Steps",
                icon: "shoeprints.fill",
                color: .cyan
            )

            Divider()
                .frame(height: 60)
                .background(.white.opacity(0.2))

            statItem(
                value: formattedDistance,
                label: "Distance",
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                color: .teal
            )

            Divider()
                .frame(height: 60)
                .background(.white.opacity(0.2))

            statItem(
                value: "\(Int(workoutManager.activeCalories))",
                label: "Calories",
                icon: "flame.fill",
                color: .orange
            )
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Map Content

    private var mapContent: some View {
        VStack(spacing: 16) {
            // Map with live route
            Map(position: $cameraPosition) {
                UserAnnotation()

                if !workoutManager.liveCoordinates.isEmpty {
                    MapPolyline(coordinates: workoutManager.liveCoordinates)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxHeight: .infinity)

            // Compact stats overlay
            compactStatsRow
        }
        .padding(.top, 16)
    }

    private var compactStatsRow: some View {
        HStack(spacing: 24) {
            compactStatItem(value: formattedDurationCompact, icon: "timer")
            compactStatItem(value: "\(workoutManager.sessionSteps.formatted())", icon: "shoeprints.fill")
            compactStatItem(value: formattedDistance, icon: "point.topleft.down.to.point.bottomright.curvepath")

            if mode == .interval {
                compactStatItem(
                    value: formattedPhaseTime,
                    icon: iwtService.currentPhase == .brisk ? "hare.fill" : "tortoise.fill"
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func compactStatItem(value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: 24) {
            // Pause/Resume button
            Button {
                if workoutManager.state == .paused {
                    workoutManager.resumeWorkout()
                    if mode == .interval {
                        iwtService.resumeSession()
                    }
                } else {
                    workoutManager.pauseWorkout()
                    if mode == .interval {
                        iwtService.pauseSession()
                    }
                }
                HapticService.shared.playSelection()
            } label: {
                Image(systemName: workoutManager.state == .paused ? "play.fill" : "pause.fill")
                    .font(.title)
                    .foregroundStyle(.black)
                    .frame(width: 70, height: 70)
                    .background(.yellow)
                    .clipShape(Circle())
            }

            // Stop button
            Button {
                Task {
                    await stopWorkout()
                }
                HapticService.shared.playSuccess()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(.red)
                    .clipShape(Circle())
            }
        }
        .padding(.top, 24)
    }

    // MARK: - Computed Properties

    private var formattedDuration: String {
        let totalSeconds = Int(workoutManager.elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private var formattedDurationCompact: String {
        let totalSeconds = Int(workoutManager.elapsedTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedDistance: String {
        let distance = max(workoutManager.sessionDistance, workoutManager.gpsDistance)
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    // MARK: - Actions

    private func stopWorkout() async {
        do {
            // Stop interval service if active
            if mode == .interval {
                _ = iwtService.endSession()
            }

            let summary = try await workoutManager.stopWorkout()
            completedWorkout = summary
            showingSummary = true
        } catch {
            print("Failed to stop workout: \(error)")
            dismiss()
        }
    }
}

// MARK: - GPS Status Pill

struct GPSStatusPill: View {
    let isRecording: Bool

    @State private var isPulsing = false

    private var statusColor: Color {
        isRecording ? .white : .orange
    }

    private var statusIcon: String {
        isRecording ? "location.fill" : "location.slash"
    }

    private var statusText: String {
        isRecording ? "Recording Route" : "No Route"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.caption.bold())
                .scaleEffect(isPulsing ? 1.2 : 1.0)

            Text(statusText)
                .font(.caption.bold())
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
        .onChange(of: isRecording) { _, _ in
            // Pulse animation when status changes
            withAnimation(.easeInOut(duration: 0.15)) {
                isPulsing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPulsing = false
                }
            }
        }
    }
}

#Preview {
    ActiveWorkoutView(mode: .classic)
}
