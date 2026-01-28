//
//  RouteWalkSessionView.swift
//  Just Walk
//
//  Main view for walking a generated route.
//  Shows the route on a map with user location tracking and stats overlay.
//

import SwiftUI
import MapKit
import CoreLocation
import HealthKit

struct RouteWalkSessionView: View {
    let route: RouteGenerator.GeneratedRoute

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var workoutManager = PhoneWorkoutManager.shared
    @ObservedObject private var stepRepository = StepRepository.shared
    @ObservedObject private var stepTrackingService = StepTrackingService.shared
    @StateObject private var turnManager = TurnByTurnManager()
    @ObservedObject private var audioCueService = AudioCueService.shared

    // Walk tracking state
    @State private var stepsAtWalkStart: Int = 0
    @State private var lastAnnouncedTurnId: UUID?

    // UI state
    @State private var showingSummary = false
    @State private var completedWorkout: PhoneWorkoutSummary?
    @State private var showingCancelAlert = false
    @State private var showingEndConfirmation = false
    @State private var startError: String?
    @State private var activeError: WalkErrorType? = nil

    var body: some View {
        mainContent
            .task {
                await startWorkout()
                turnManager.startNavigation(route: route)
            }
            .alert("End Walk?", isPresented: $showingCancelAlert) {
                Button("Continue Walking", role: .cancel) { }
                Button("Discard", role: .destructive) { handleDiscard() }
            } message: {
                Text("Your walk will not be saved.")
            }
            .alert("Error", isPresented: $showingStartError) {
                Button("OK") { handleErrorDismiss() }
            } message: {
                Text(startError ?? "Failed to start walk")
            }
            .sheet(isPresented: $showingSummary) { summarySheetContent }
            .overlay { endConfirmationOverlay }
            .applyOnChangeHandlers(
                showingSummary: showingSummary,
                hasGPSSignal: workoutManager.hasGPSSignal,
                coordinatesCount: workoutManager.liveCoordinates.count,
                currentInstructionId: turnManager.currentInstruction?.id,
                isOffRoute: turnManager.isOffRoute,
                startError: startError,
                onSummaryChange: handleSummaryChange,
                onGPSChange: handleGPSChange,
                onLocationUpdate: handleLocationUpdate,
                onTurnChange: handleTurnChange,
                onOffRouteChange: handleOffRouteChange,
                onStartErrorChange: handleStartErrorChange
            )
            .onDisappear { turnManager.stopNavigation() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            ActiveRouteMapView(
                route: route,
                userLocation: workoutManager.liveCoordinates.last
            )
            .ignoresSafeArea()

            contentOverlay
            errorBannerOverlay
        }
    }

    // MARK: - Content Overlay

    private var contentOverlay: some View {
        VStack(spacing: 0) {
            routeWalkHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)

            turnBannerSection

            if workoutManager.state == .paused {
                PausedIndicator()
                    .padding(.top, 12)
            }

            Spacer()

            statsOverlaySection
        }
    }

    @ViewBuilder
    private var turnBannerSection: some View {
        if turnManager.isNavigating, let instruction = turnManager.currentInstruction {
            TurnBannerView(
                instruction: instruction,
                isOffRoute: turnManager.isOffRoute,
                voiceEnabled: audioCueService.routeGuidanceEnabled,
                onToggleVoice: { audioCueService.routeGuidanceEnabled.toggle() }
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var statsOverlaySection: some View {
        RouteWalkStatsOverlay(
            steps: stepsThisWalk,
            distance: currentDistance,
            duration: workoutManager.elapsedTime,
            isPaused: workoutManager.state == .paused,
            onPause: handlePause,
            onResume: handleResume,
            onEnd: handleEndTap
        )
    }

    // MARK: - Error Banner Overlay

    private var errorBannerOverlay: some View {
        VStack {
            if let error = activeError {
                WalkErrorBanner(
                    errorType: error,
                    onDismiss: makeDismissHandler(for: error)
                )
                .padding(.horizontal, 24)
                .padding(.top, 80)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: activeError)
    }

    // MARK: - End Confirmation Overlay

    @ViewBuilder
    private var endConfirmationOverlay: some View {
        if showingEndConfirmation {
            EndWalkConfirmationView(
                steps: stepsThisWalk,
                durationSeconds: workoutManager.elapsedTime,
                distanceMeters: currentDistance,
                onKeepWalking: handleKeepWalking,
                onEndWalk: handleConfirmEnd
            )
            .transition(.opacity)
            .animation(.easeOut(duration: 0.2), value: showingEndConfirmation)
        }
    }

    // MARK: - Summary Sheet

    @ViewBuilder
    private var summarySheetContent: some View {
        if let summary = completedWorkout, let workout = summary.workout {
            WorkoutSummaryView(workout: workout, originalRoute: route)
        }
    }

    // MARK: - State for Error Alert

    @State private var showingStartError = false

    // MARK: - Action Handlers

    private func handlePause() {
        workoutManager.pauseWorkout()
    }

    private func handleResume() {
        workoutManager.resumeWorkout()
    }

    private func handleEndTap() {
        if shouldShowEndConfirmation {
            showingEndConfirmation = true
        } else {
            Task { await stopWorkout() }
        }
    }

    private func handleKeepWalking() {
        withAnimation(.easeOut(duration: 0.2)) {
            showingEndConfirmation = false
        }
    }

    private func handleConfirmEnd() {
        showingEndConfirmation = false
        Task { await stopWorkout() }
    }

    private func handleDiscard() {
        workoutManager.cancelWorkout()
        dismiss()
    }

    private func handleErrorDismiss() {
        startError = nil
        dismiss()
    }

    // MARK: - Change Handlers

    private func handleSummaryChange(_ oldValue: Bool, _ newValue: Bool) {
        if !newValue { dismiss() }
    }

    private func handleGPSChange(_ oldValue: Bool, _ newValue: Bool) {
        withAnimation {
            if !newValue {
                activeError = .gpsSignalLost
            } else if activeError == .gpsSignalLost {
                activeError = nil
            }
        }
    }

    private func handleLocationUpdate() {
        if let latest = workoutManager.liveCoordinates.last {
            turnManager.updateUserLocation(latest)
        }
    }

    private func handleTurnChange(_ oldId: UUID?, _ newId: UUID?) {
        if let instruction = turnManager.currentInstruction,
           oldId != newId,
           lastAnnouncedTurnId != newId {
            lastAnnouncedTurnId = newId
            audioCueService.announceTurn(instruction)
            HapticService.shared.playTurnAhead()
        }
    }

    private func handleOffRouteChange(_ oldValue: Bool, _ newValue: Bool) {
        if newValue && !oldValue {
            audioCueService.announceOffRoute()
            HapticService.shared.playOffRouteWarning()
        } else if !newValue && oldValue {
            audioCueService.announceBackOnRoute()
            HapticService.shared.playBackOnRoute()
        }
    }

    private func handleStartErrorChange(_ oldValue: String?, _ newValue: String?) {
        showingStartError = newValue != nil
    }

    // MARK: - Header

    private var routeWalkHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Route Walk")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                // Route info
                HStack(spacing: 8) {
                    GPSStatusPill(isRecording: workoutManager.isRecordingRoute)

                    Text("\(formatDistance(route.totalDistance)) route")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Close/Cancel button
            Button {
                showingCancelAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Computed Properties

    private var stepsThisWalk: Int {
        max(0, workoutManager.sessionSteps)
    }

    private var currentDistance: Double {
        max(workoutManager.sessionDistance, workoutManager.gpsDistance)
    }

    private var shouldShowEndConfirmation: Bool {
        let durationMet = workoutManager.elapsedTime >= 300  // 5 minutes
        let stepsMet = stepsThisWalk >= 500
        let distanceMet = currentDistance >= 402.336  // 0.25 mi
        return durationMet || stepsMet || distanceMet
    }

    // MARK: - Formatters

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles < 1 {
            return String(format: "%.2f mi", miles)
        }
        return String(format: "%.1f mi", miles)
    }

    // MARK: - Helpers

    private func makeDismissHandler(for error: WalkErrorType) -> (() -> Void)? {
        if error == .gpsSignalLost {
            return nil
        } else {
            return { activeError = nil }
        }
    }

    // MARK: - Actions

    private func startWorkout() async {
        // Get real-time today's steps from CMPedometer
        if let pedometerSteps = await stepTrackingService.queryTodayStepsFromPedometer() {
            stepsAtWalkStart = pedometerSteps
        } else {
            stepsAtWalkStart = stepRepository.todaySteps
        }

        // Cancel any stale workout state first
        if workoutManager.state != .idle {
            workoutManager.cancelWorkout()
        }

        do {
            try await workoutManager.startWorkout()
        } catch {
            startError = error.localizedDescription
        }
    }

    private func stopWorkout() async {
        HapticService.shared.playIncrementMilestone()

        do {
            let summary = try await workoutManager.stopWorkout()
            completedWorkout = summary
            showingSummary = true
        } catch {
            print("Failed to stop workout: \(error)")
            dismiss()
        }
    }
}

// MARK: - onChange Handlers Extension
// Extracted to reduce type-checker complexity from chained onChange modifiers

private extension View {
    func applyOnChangeHandlers(
        showingSummary: Bool,
        hasGPSSignal: Bool,
        coordinatesCount: Int,
        currentInstructionId: UUID?,
        isOffRoute: Bool,
        startError: String?,
        onSummaryChange: @escaping (Bool, Bool) -> Void,
        onGPSChange: @escaping (Bool, Bool) -> Void,
        onLocationUpdate: @escaping () -> Void,
        onTurnChange: @escaping (UUID?, UUID?) -> Void,
        onOffRouteChange: @escaping (Bool, Bool) -> Void,
        onStartErrorChange: @escaping (String?, String?) -> Void
    ) -> some View {
        self
            .onChange(of: showingSummary) { onSummaryChange($0, $1) }
            .onChange(of: hasGPSSignal) { onGPSChange($0, $1) }
            .onChange(of: coordinatesCount) { _, _ in onLocationUpdate() }
            .onChange(of: currentInstructionId) { onTurnChange($0, $1) }
            .onChange(of: isOffRoute) { onOffRouteChange($0, $1) }
            .onChange(of: startError) { onStartErrorChange($0, $1) }
    }
}

// MARK: - Preview

#Preview {
    // Create a mock route for preview
    let coordinates = [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7759, longitude: -122.4174),
        CLLocationCoordinate2D(latitude: 37.7769, longitude: -122.4184),
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    ]
    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)

    let mockRoute = RouteGenerator.GeneratedRoute(
        polyline: polyline,
        totalDistance: 1609.34,
        estimatedTime: 1200,
        waypoints: Array(coordinates.dropFirst().dropLast()),
        coordinates: coordinates
    )

    return RouteWalkSessionView(route: mockRoute)
}
