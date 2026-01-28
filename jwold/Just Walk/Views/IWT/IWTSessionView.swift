//
//  IWTSessionView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI
import MapKit
import CoreLocation

/// Full-screen IWT walking session view
struct IWTSessionView: View {

    @StateObject private var viewModel = IWTSessionViewModel()
    @ObservedObject private var workoutManager = PhoneWorkoutManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var showEndConfirmation = false
    @State private var showConfigPicker = false
    @State private var showSilentModeWarning = true
    @State private var capturedRouteCoordinates: [CLLocationCoordinate2D] = []
    @State private var showPowerWalkPaywall = false

    var mode: WalkMode = .interval

    /// The actual session mode from the service (more reliable than passed mode due to SwiftUI state timing)
    private var effectiveMode: WalkMode {
        IWTService.shared.sessionMode
    }

    var body: some View {
        ZStack {
            // Background gradient based on phase
            phaseBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Silent mode warning banner (only for interval mode)
                if showSilentModeWarning && effectiveMode == .interval {
                    silentModeWarningBanner
                }

                // Header
                header

                if viewModel.isSessionActive {
                    // Active session view
                    activeSessionContent
                } else {
                    // Show a loader or simple "Starting..." text briefly if needed,
                    // though onAppear happens fast.
                    // Or keep 'activeSessionContent' as it will render initial state.
                    activeSessionContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Prevent content from ignoring safe areas when returning from Live Activity
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            // CRITICAL: Sync state from service first to prevent timer reset
            // This ensures the ViewModel has the correct phase time when view appears
            viewModel.syncStateFromService()

            // Check the service's state directly, not the ViewModel's potentially stale state
            // This prevents restarting the session when returning from lock screen
            // NOTE: Use effectiveMode (from service) instead of passed `mode` to avoid SwiftUI state timing issues
            if !IWTService.shared.isSessionActive {
                viewModel.startSession(mode: effectiveMode)

                // Start GPS route tracking
                Task {
                    // Cancel any stale workout state first
                    if workoutManager.state != .idle {
                        workoutManager.cancelWorkout()
                    }

                    do {
                        try await workoutManager.startWorkout()
                        print("✅ GPS workout started successfully")
                    } catch {
                        print("❌ GPS workout failed to start: \(error.localizedDescription)")
                    }
                }
            }
            // Auto-hide warning after 8 seconds
            if effectiveMode == .interval {
                Task {
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    withAnimation {
                        showSilentModeWarning = false
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showCompletionSheet) {
            if let summary = viewModel.sessionSummary {
                WalkSummaryView(
                    summaryData: WalkSummaryData(
                        sessionSummary: summary,
                        stepsBeforeWalk: viewModel.stepsAtSessionStart,
                        dailyGoal: viewModel.dailyGoal,
                        walkMode: viewModel.sessionMode,
                        routeCoordinates: capturedRouteCoordinates
                    ),
                    onDismiss: { dismiss() },
                    onShowPaywall: { showPowerWalkPaywall = true }
                )
            }
        }
        .fullScreenCover(isPresented: $showPowerWalkPaywall) {
            ProPaywallView {
                showPowerWalkPaywall = false
            }
        }
        .onChange(of: viewModel.currentPhase) { _, newPhase in
            if newPhase != .paused {
                playIntenseHaptic()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // CRITICAL: Sync state when app returns to foreground
                // This ensures timer shows correct remaining time, not reset to phase start
                viewModel.syncStateFromService()
            }
        }
    }
    
    private func playIntenseHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        
        // Play a triple pulse for maximum noticeability
        Task {
            for _ in 0..<3 {
                generator.impactOccurred(intensity: 1.0)
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s pause
            }
        }
    }

    // MARK: - Silent Mode Warning Banner

    private var silentModeWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Turn off Silent Mode")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text("Notifications will alert you when to change pace")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Button {
                withAnimation {
                    showSilentModeWarning = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.4))
        .background(.ultraThinMaterial)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Background

    private var phaseBackground: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.5), value: viewModel.currentPhase)
    }

    private var backgroundColors: [Color] {
        switch viewModel.currentPhase {
        case .warmup:
            return [Color(hex: "FF9500").opacity(0.8), Color.yellow.opacity(0.6)]
        case .brisk:
            // Orange gradient
            return [Color(hex: "FF9500").opacity(0.9), Color(hex: "FF6B00").opacity(0.7)]
        case .slow:
            // Teal gradient (matches Just Walk)
            return [Color(hex: "00C7BE").opacity(0.9), Color(hex: "34C759").opacity(0.7)]
        case .cooldown:
            return [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)]
        case .paused:
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        case .completed:
            return [Color.purple.opacity(0.8), Color.pink.opacity(0.6)]
        case .classic:
            return [Color.cyan.opacity(0.8), Color.green.opacity(0.6)]
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            // Center: Title and Phase Counter
            VStack(spacing: 4) {
                Text("Power Walk")
                    .font(.headline)
                    .foregroundStyle(.white)

                if viewModel.isSessionActive && !viewModel.isPaused && viewModel.sessionMode != .classic {
                    Text(viewModel.phaseCounterDisplay)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Buttons (Left & Right)
            HStack {
                // Left: dismiss button (only when session not active)
                if !viewModel.isSessionActive {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                Spacer()

                // Skip Button (Right) - text style
                if viewModel.isSessionActive && viewModel.sessionMode != .classic {
                    Button {
                        viewModel.skipPhase()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.forward.2")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Active Session Content

    private var activeSessionContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)

            // Phase indicator
            phaseIndicator

            // Main timer
            mainTimer

            // Phase instruction (rotates every 8 seconds)
            Text(viewModel.currentInstruction)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentInstructionIndex)

            Spacer(minLength: 8)

            // Session stats
            sessionStats
                .padding(.bottom, 12)

            // Control buttons
            controlButtons
        }
    }

    private var phaseIndicator: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.currentPhase.icon)
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: viewModel.currentPhase)

            Text(viewModel.currentPhase.displayName.uppercased())
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
        }
    }

    private var mainTimer: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(.white.opacity(0.3), lineWidth: 12)
                .frame(width: 200, height: 200)

            Circle()
                .trim(from: 0, to: viewModel.phaseProgress)
                .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: viewModel.phaseProgress)

            // Warning pulse (10-second countdown)
            if viewModel.isWarningCountdown {
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 4)
                    .frame(width: 220, height: 220)
                    .scaleEffect(1.05)
                    .opacity(0.8)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isWarningCountdown)
            }

            // Time display
            VStack(spacing: 4) {
                if viewModel.sessionMode == .classic {
                    Text(viewModel.formattedTotalTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("duration")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text(viewModel.formattedPhaseTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    private var sessionStats: some View {
        HStack(spacing: 32) {
            sessionStatItem(
                value: "\(viewModel.sessionSteps)",
                label: "Steps",
                icon: "shoeprints.fill"
            )

            sessionStatItem(
                value: viewModel.formattedDistance,
                label: "Distance",
                icon: "point.topleft.down.to.point.bottomright.curvepath"
            )

            sessionStatItem(
                value: viewModel.formattedTotalTime,
                label: "Time",
                icon: "clock.fill"
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private func sessionStatItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private var controlButtons: some View {
        HStack(spacing: 24) {
            // End button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()

                // Capture route coordinates before stopping
                capturedRouteCoordinates = workoutManager.liveCoordinates
                print("📍 Captured \(capturedRouteCoordinates.count) GPS coordinates")
                print("📍 Workout state: \(workoutManager.state.rawValue)")
                print("📍 Is recording route: \(workoutManager.isRecordingRoute)")

                // Stop GPS workout tracking and capture HealthKit workout ID
                Task {
                    do {
                        let summary = try await workoutManager.stopWorkout()
                        let hkWorkoutId = summary.hkWorkoutId
                        print("📍 HealthKit workout ID: \(hkWorkoutId?.uuidString ?? "nil")")
                        print("📍 Workout summary received: steps=\(summary.steps), distance=\(summary.distance)")

                        // End IWT session with HealthKit workout ID for later fetching
                        await MainActor.run {
                            viewModel.endSession(hkWorkoutId: hkWorkoutId)
                        }
                    } catch {
                        print("❌ Failed to stop workout: \(error)")
                        // Still end the session, but without hkWorkoutId
                        await MainActor.run {
                            viewModel.endSession(hkWorkoutId: nil)
                        }
                    }
                }
            } label: {
                Label("End", systemImage: "stop.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            // Pause/Resume button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                if viewModel.isPaused {
                    viewModel.resumeSession()
                } else {
                    viewModel.pauseSession()
                }
            } label: {
                Label(viewModel.isPaused ? "Resume" : "Pause", systemImage: viewModel.isPaused ? "play.fill" : "pause.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.isPaused ? Color.green : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    // MARK: - Pre-Session Content (Removed)
    // Session now auto-starts based on Settings.
}

// MARK: - Session Completion View

struct SessionCompletionView: View {
    let summary: IWTSessionSummary?
    let routeCoordinates: [CLLocationCoordinate2D]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            // Header
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow)

                Text("Great Job!")
                    .font(.title3.bold())
            }

            // Route map (if coordinates exist)
            if routeCoordinates.count > 1 {
                CompactRouteMap(coordinates: routeCoordinates)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            if let summary = summary {
                // Stats row - 3 items horizontal
                HStack(spacing: 0) {
                    summaryItem(
                        title: "Time",
                        value: summary.formattedDuration,
                        icon: "clock.fill"
                    )

                    Divider()
                        .frame(height: 50)

                    summaryItem(
                        title: "Steps",
                        value: "\(summary.steps)",
                        icon: "shoeprints.fill"
                    )

                    Divider()
                        .frame(height: 50)

                    summaryItem(
                        title: "Distance",
                        value: String(format: "%.2f mi", summary.distance * 0.000621371),
                        icon: "map.fill"
                    )
                }
                .padding(.horizontal)
            }

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .presentationDetents([.fraction(routeCoordinates.count > 1 ? 0.75 : 0.4)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }

    private func summaryItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)

            Text(value)
                .font(.headline.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Route Map

struct CompactRouteMap: View {
    let coordinates: [CLLocationCoordinate2D]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            // Route polyline (blue)
            MapPolyline(coordinates: coordinates)
                .stroke(.blue, lineWidth: 4)

            // Start marker (green)
            if let start = coordinates.first {
                Annotation("", coordinate: start) {
                    Circle()
                        .fill(.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                }
            }

            // End marker (red)
            if let end = coordinates.last, coordinates.count > 1 {
                Annotation("", coordinate: end) {
                    Circle()
                        .fill(.red)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                }
            }
        }
        .mapStyle(.standard)
        .mapControlVisibility(.hidden)
        .onAppear {
            calculateCameraPosition()
        }
    }

    private func calculateCameraPosition() {
        guard !coordinates.isEmpty else { return }

        // Calculate bounding box
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }

        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else { return }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        // Calculate span with padding
        let latDelta = (maxLat - minLat) * 1.4 // 40% padding
        let lonDelta = (maxLon - minLon) * 1.4

        // Ensure minimum span for very short routes
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.005),
            longitudeDelta: max(lonDelta, 0.005)
        )

        let region = MKCoordinateRegion(center: center, span: span)
        cameraPosition = .region(region)
    }
}

#Preview {
    IWTSessionView()
}
