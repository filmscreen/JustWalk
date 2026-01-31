//
//  FatBurnActiveView.swift
//  JustWalk
//
//  Active Fat Burn Zone walk with real-time HR monitoring,
//  3 zone states (below/in/above), hysteresis, and time-in-zone tracking.
//

import SwiftUI

struct FatBurnActiveView: View {
    @Environment(AppState.self) private var appState
    @StateObject private var walkSession = WalkSessionManager.shared
    @StateObject private var zoneManager = FatBurnZoneManager.shared
    @StateObject private var watchConnectivity = PhoneConnectivityManager.shared

    @State private var showEndConfirmation = false
    @State private var timer: Timer?

    // Background color animation
    @State private var bgColor: Color = FatBurnZoneManager.ZoneState.inZone.backgroundColor
    @State private var previousZoneState: FatBurnZoneManager.ZoneState = .belowZone

    var body: some View {
        ZStack {
            // Animated background
            bgColor.opacity(0.25)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: zoneManager.zoneState)

            JW.Color.backgroundPrimary.opacity(0.7)
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

                // Hero HR display
                VStack(spacing: JW.Spacing.md) {
                    if zoneManager.currentHR > 0 {
                        Text("\(zoneManager.currentHR)")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundStyle(JW.Color.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.default, value: zoneManager.currentHR)
                    } else {
                        Text("--")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundStyle(JW.Color.textSecondary)
                    }

                    Text("bpm")
                        .font(JW.Font.title3)
                        .foregroundStyle(JW.Color.textSecondary)

                    // Zone state label (only show when we have HR data)
                    if zoneManager.currentHR > 0 {
                        Text(zoneManager.zoneState.label)
                            .font(JW.Font.title2.bold())
                            .foregroundStyle(stateColor)
                            .contentTransition(.interpolate)
                            .animation(.easeInOut(duration: 0.3), value: zoneManager.zoneState)

                        // Guidance text
                        if let guidance = zoneManager.zoneState.guidance {
                            Text(guidance)
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textSecondary)
                                .transition(.opacity)
                        }
                    } else {
                        if watchConnectivity.isWatchReachable {
                            Text("Waiting for heart rate...")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textSecondary)
                        } else {
                            Text("Apple Watch not connected")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textTertiary)
                        }
                    }
                }

                Spacer()

                // Zone scale
                ZoneScaleView(
                    zoneLow: zoneManager.zoneLow,
                    zoneHigh: zoneManager.zoneHigh,
                    currentHR: zoneManager.currentHR
                )
                .padding(.horizontal, JW.Spacing.xxl)

                // Time in zone
                VStack(spacing: JW.Spacing.xs) {
                    let percent = Int(zoneManager.zonePercentage)
                    Text("Time in zone: \(zoneManager.timeInZoneFormatted) (\(percent)%)")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: zoneManager.timeInZoneSeconds)
                }
                .padding(.top, JW.Spacing.xl)

                Spacer()

                // Controls
                WalkControlBar(
                    isPaused: walkSession.isPaused,
                    onTogglePause: {
                        if walkSession.isPaused {
                            walkSession.resumeWalk()
                            resumeHRTracking()
                        } else {
                            walkSession.pauseWalk()
                            pauseHRTracking()
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
            Button("End", role: .destructive) {
                endWalk()
            }
            Button("Keep Going", role: .cancel) {}
        }
        .onAppear {
            startHRTracking()
            JustWalkHaptics.prepareForFatBurn()
            appState.isViewingActiveWalk = true
        }
        .onDisappear {
            stopHRTracking()
            appState.isViewingActiveWalk = false
        }
        .onChange(of: zoneManager.zoneState) { _, newState in
            withAnimation(.easeInOut(duration: 0.5)) {
                bgColor = newState.backgroundColor
            }

            // Fire haptics/notifications based on zone transition
            let wasInZone = previousZoneState == .inZone
            switch newState {
            case .inZone:
                JustWalkHaptics.fatBurnEnteredZone()
            case .belowZone:
                if wasInZone {
                    // Immediate notification on zone exit (10s repeat alerts continue separately)
                    NotificationManager.shared.sendFatBurnOutOfRangeNotification(isBelowZone: true)
                }
            case .aboveZone:
                if wasInZone {
                    // Immediate notification on zone exit (10s repeat alerts continue separately)
                    NotificationManager.shared.sendFatBurnOutOfRangeNotification(isBelowZone: false)
                }
            }
            previousZoneState = newState
        }
        .onChange(of: zoneManager.shouldTriggerOutOfRangeHaptic) { _, state in
            guard let state else { return }
            // Watch haptics are handled by WatchWalkSessionManager independently
            // Notification provides text instruction (always fires for clear guidance)
            switch state {
            case .belowZone:
                NotificationManager.shared.sendFatBurnOutOfRangeNotification(isBelowZone: true)
            case .aboveZone:
                NotificationManager.shared.sendFatBurnOutOfRangeNotification(isBelowZone: false)
            case .inZone:
                break
            }
            zoneManager.shouldTriggerOutOfRangeHaptic = nil
        }
    }

    // MARK: - Colors

    private var stateColor: Color {
        switch zoneManager.zoneState {
        case .belowZone: return JW.Color.accentBlue
        case .inZone: return JW.Color.accent
        case .aboveZone: return JW.Color.streak
        }
    }

    // MARK: - HR Tracking

    private func startHRTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard walkSession.isWalking, !walkSession.isPaused else { return }
            zoneManager.tick()
        }
    }

    private func pauseHRTracking() {
        // Timer keeps running but tick() checks isPaused
    }

    private func resumeHRTracking() {
        // Timer keeps running, tick() will resume
    }

    private func stopHRTracking() {
        timer?.invalidate()
        timer = nil
    }

    private func endWalk() {
        stopHRTracking()
        zoneManager.stopSession()

        Task {
            if var walk = await walkSession.endWalk() {
                // Enhance walk with fat burn data
                walk.fatBurnTimeInZoneSeconds = zoneManager.timeInZoneSeconds
                walk.fatBurnZonePercentage = zoneManager.zonePercentage
                walk.fatBurnZoneLow = zoneManager.zoneLow
                walk.fatBurnZoneHigh = zoneManager.zoneHigh
                walk.heartRateAvg = zoneManager.currentHR // Simplified; real avg from Watch in 3D

                // Update the completed walk with fat burn data
                // Note: Usage recording is handled in WalkTabView with 5-minute minimum check
                walkSession.completedWalk = walk
            }
        }
    }
}

#Preview {
    FatBurnActiveView()
}
