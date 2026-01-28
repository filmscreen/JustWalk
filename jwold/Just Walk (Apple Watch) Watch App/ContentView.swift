//
//  ContentView.swift
//  Just Walk Watch App
//
//  Created by Just Walk Team.
//  Design aligned with iOS app (Blue/Teal/Cyan brand colors).
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthManager = WatchHealthManager.shared
    @ObservedObject private var sessionManager = WatchSessionManager.shared

    // Celebration State
    @AppStorage("lastCelebrationDate") private var lastCelebrationDate: Double = 0
    @State private var showConfetti = false
    @AppStorage("watchCelebrationPhrase") private var currentCelebrationPhrase: String = "Goal Reached!"
    @State private var confettiHideWorkItem: DispatchWorkItem?

    // Pro Upgrade Prompt State
    @State private var showProUpgradePrompt = false

    // Goal Selection Sheet State
    @State private var showGoalSelection = false

    var body: some View {
        NavigationStack {
            if sessionManager.currentPhase == .idle {
                WatchWalkView()  // Updated to new vertical scroll layout
            } else if sessionManager.currentPhase == .summary {
                WatchSummaryView()  // New dedicated summary view
            } else if sessionManager.sessionMode == .postMeal {
                PostMealActiveWatchView()  // Post-meal 10-min countdown
            } else if sessionManager.sessionMode == .classic {
                JustWalkSessionView()
            } else {
                PowerWalkSessionView()  // Interval mode uses new phase-colored view
            }
        }
        .onAppear {
            // Check current authorization status
            healthManager.checkAuthorizationStatus()

            Task {
                await healthManager.requestAuthorization()
                // Force refresh steps when app appears (bypasses throttle)
                healthManager.handleAppBecomeActive()
            }
        }
        .onChange(of: healthManager.todaySteps) { _, _ in
            checkForCelebration()
        }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }
    
    private func checkForCelebration() {
        if healthManager.todaySteps >= healthManager.stepGoal {
            let lastDate = Date(timeIntervalSince1970: lastCelebrationDate)
            
            // Only auto-celebrate once per day
            if !Calendar.current.isDateInToday(lastDate) {
                pickCelebrationPhrase()
                lastCelebrationDate = Date().timeIntervalSince1970
                triggerCelebration()
            }
        }
    }
    
    /// Manually trigger celebration (called when user taps progress ring)
    private func triggerCelebration() {
        // Cancel any pending hide timer
        confettiHideWorkItem?.cancel()
        
        // Reset and show confetti fresh
        showConfetti = false
        DispatchQueue.main.async {
            showConfetti = true
        }
        
        // Haptic Feedback (Success + Emphasis)
        WKInterfaceDevice.current().play(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            WKInterfaceDevice.current().play(.click)
        }
        
        // Schedule hide after 4 seconds (cancellable)
        let workItem = DispatchWorkItem {
            withAnimation {
                showConfetti = false
            }
        }
        confettiHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }
    
    // MARK: - Dashboard

    /// Progress ring gradient (matches iPhone - teal→cyan→blue→teal)
    private var progressRingGradient: AngularGradient {
        AngularGradient(
            colors: [.teal, .cyan, .blue, .teal],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var dashboardView: some View {
        let progress = Double(healthManager.todaySteps) / Double(healthManager.stepGoal)
        let trimEnd = min(CGFloat(progress), 1.0)

        return VStack {
            // Permission denied banner
            if !healthManager.isAuthorized {
                deniedPermissionsBanner
            }

            // Steps Ring
            ZStack {
                // Background Ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                // Progress Ring with Gradient (matches iPhone)
                Circle()
                    .trim(from: 0, to: trimEnd)
                    .stroke(
                        progressRingGradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Overlap ring for >100% progress
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress - 1.0))
                        .stroke(
                            progressRingGradient,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                // Center Stats
                VStack(spacing: 0) {
                    if healthManager.todaySteps >= healthManager.stepGoal {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .padding(.bottom, 2)
                            .symbolEffect(.pulse, options: .repeating)

                        Text(currentCelebrationPhrase)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.teal)
                    }

                    // Steps (Large)
                    Text("\(healthManager.todaySteps)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .contentTransition(.numericText())

                    // Distance - uses brand cyan
                    Text(formattedDistance)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.cyan)
                }
            }
            .padding(4)
            // Tap to replay celebration (only when goal is reached)
            .onTapGesture {
                if healthManager.todaySteps >= healthManager.stepGoal {
                    triggerCelebration()
                }
            }

        }
        .padding()
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

    // MARK: - Start Session View

    var startSessionView: some View {
        VStack(spacing: 12) {
            // Classic Walk Button (mint/green - matches iPhone)
            Button {
                if sessionManager.isPro {
                    showGoalSelection = true
                } else {
                    WKInterfaceDevice.current().play(.failure)
                    showProUpgradePrompt = true
                }
            } label: {
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                    Text("Classic Walk")
                        .font(.headline)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .tint(.mint)
            .clipShape(Capsule())
            .sheet(isPresented: $showGoalSelection) {
                WatchModePickerView(
                    sessionManager: sessionManager,
                    onStartOpenWalk: {
                        showGoalSelection = false
                        sessionManager.currentGoal = .none
                        sessionManager.startSession(mode: .classic, goal: .none)
                    },
                    onStartWithGoal: { goal in
                        showGoalSelection = false
                        sessionManager.currentGoal = goal
                        sessionManager.startSession(mode: .classic, goal: goal)
                    },
                    onStartInterval: {
                        showGoalSelection = false
                        sessionManager.startSession(mode: .interval)
                    }
                )
            }

            // Interval Walk Button (blue - matches iPhone brand primary)
            Button {
                if sessionManager.isPro {
                    sessionManager.startSession(mode: .interval)
                } else {
                    WKInterfaceDevice.current().play(.failure)
                    showProUpgradePrompt = true
                }
            } label: {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title2)
                    Text("Interval Walk")
                        .font(.headline)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .tint(.blue)
            .clipShape(Capsule())
        }
        .padding(.horizontal)
        .sheet(isPresented: $showProUpgradePrompt) {
            proUpgradePromptView
        }
    }

    // MARK: - Pro Upgrade Prompt View

    private var proUpgradePromptView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow)

                Text("Pro Feature")
                    .font(.headline)

                Text("Walking sessions require Just Walk Pro. Upgrade on your iPhone to unlock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Dismiss") {
                    showProUpgradePrompt = false
                }
                .tint(.gray)
            }
            .padding()
        }
    }
    
    // MARK: - Helpers

    private var formattedDistance: String {
        WatchDistanceUnit.formatDistance(healthManager.todayDistance)
    }

    /// Format session distance (sessionManager.distance is in miles)
    private var formattedSessionDistance: String {
        let unit = WatchDistanceUnit.preferred
        let distanceInMeters = sessionManager.distance * 1609.34  // Convert miles to meters
        let value = distanceInMeters * unit.conversionFromMeters
        return String(format: "%.2f", value)
    }

    /// Available celebration phrases
    private let celebrationPhrases = [
        "Crushed it!",
        "Champion!",
        "Unstoppable!",
        "Goal Reached!",
        "Amazing work!",
        "Legend!"
    ]
    
    /// Pick a stable celebration phrase (called once when goal is reached)
    private func pickCelebrationPhrase() {
        currentCelebrationPhrase = celebrationPhrases.randomElement() ?? "Goal Reached!"
    }
    
    // MARK: - Session View
    
    @ViewBuilder
    var sessionView: some View {
        if sessionManager.currentPhase == .summary {
            summaryView
        } else {
            VStack(spacing: 6) {
                // Header
                Text(sessionManager.currentPhase.title)
                    .font(.headline)
                    .foregroundStyle(sessionManager.currentPhase.color)
                
                // Timer Display
                if sessionManager.sessionMode == .classic {
                    // Classic Mode: Count Up from start (mint matches button color)
                    if let startTime = sessionManager.sessionStartTime {
                        Text(startTime, style: .timer)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.mint)
                    } else {
                        Text("00:00")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    
                    metricsView
                    .padding(.horizontal)
                    
                } else {
                    // Interval Mode: Countdown Timer
                    if let endTime = sessionManager.phaseEndTime {
                        Text(timerInterval: Date()...endTime, countsDown: true)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    } else {
                        Text(sessionManager.formattedTime)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    
                    if sessionManager.currentPhase != .completed && sessionManager.currentPhase != .idle {
                        Text("Interval \(sessionManager.currentInterval) of \(sessionManager.totalIntervals)")
                            .font(.caption2) // Reduced from caption
                            .foregroundStyle(.secondary)
                    }
                    
                    // Add Metrics to Interval Mode too
                    metricsView
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Controls
                if sessionManager.currentPhase == .completed {
                    Button("Done") {
                        sessionManager.stopSession()
                    }
                    .tint(.green)
                    .frame(height: 40) // Reduced height
                } else {
                    HStack(spacing: 20) {
                        // Stop Button
                        Button(role: .destructive) {
                            playStrongEndHaptic()
                            sessionManager.stopSession()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                        }
                        .background(Color.red.opacity(0.3))
                        .clipShape(Circle())
                        .frame(width: 40, height: 40)
                        
                        // Pause/Resume Button
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            if sessionManager.isPaused {
                                sessionManager.resumeSession()
                            } else {
                                sessionManager.pauseSession()
                            }
                        } label: {
                            Image(systemName: sessionManager.isPaused ? "play.fill" : "pause.fill")
                                .font(.title3)
                        }
                        .foregroundStyle(.yellow)
                        .background(Color.yellow.opacity(0.3))
                        .clipShape(Circle())
                        .frame(width: 40, height: 40)
                        
                        // Skip Button (Only for Interval Mode)
                        if sessionManager.sessionMode == .interval {
                            Button {
                                sessionManager.skipToNextPhase()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Circle())
                            .frame(width: 40, height: 40)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 2) // Reduced from 4
            .padding(.bottom, 2)
        }
    }
    
    // MARK: - Metrics View
    
    var metricsView: some View {
        VStack(spacing: 0) {
            // Row 1: HR & Calories
            HStack(spacing: 0) {
                // Heart Rate
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("\(Int(sessionManager.currentHeartRate))")
                        .font(.headline)
                        .monospacedDigit()
                    Text("BPM")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 16)
                
                // Calories
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(Int(sessionManager.activeCalories))")
                        .font(.headline)
                        .monospacedDigit()
                    Text("CAL")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Row 2: Steps & Distance
            HStack(spacing: 0) {
                // Steps (cyan - brand accent)
                HStack(spacing: 2) {
                    Image(systemName: "shoeprints.fill")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    Text("\(sessionManager.sessionSteps)")
                        .font(.headline)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 16)

                // Distance (teal - brand secondary)
                HStack(spacing: 2) {
                    Image(systemName: "map.fill")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                    Text(formattedSessionDistance)
                        .font(.headline)
                        .monospacedDigit()
                    Text(WatchDistanceUnit.preferred.abbreviation)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    // MARK: - Summary View

    var summaryView: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 6) {
                // Brand-consistent colors
                summaryItem(title: "Duration", value: formatDuration(sessionManager.finalDuration), color: .white)
                summaryItem(title: "Steps", value: "\(sessionManager.sessionSteps)", color: .cyan)
                summaryItem(title: "Distance", value: "\(formattedSessionDistance) \(WatchDistanceUnit.preferred.abbreviation)", color: .teal)
                summaryItem(title: "Avg HR", value: "\(Int(sessionManager.averageHeartRate)) BPM", color: .red)
            }
            .padding(.top, 12)

            Spacer()

            Button("Done") {
                sessionManager.closeSummary()
            }
            .tint(.teal)
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
    }
    
    private func summaryItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Play MAXIMUM intensity haptic pattern when ending a workout
    /// Uses the strongest possible combination of haptic types
    private func playStrongEndHaptic() {
        let device = WKInterfaceDevice.current()
        Task {
            // === MAXIMUM INTENSITY END PATTERN ===

            // Opening stop signal
            device.play(.stop)
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // 5 rapid notification bursts (strongest haptic type)
            for _ in 0..<5 {
                device.play(.notification)
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms (very rapid)
            }

            // Brief pause
            try? await Task.sleep(nanoseconds: 120_000_000) // 120ms

            // Triple direction down (descending "stopping" feel)
            for _ in 0..<3 {
                device.play(.directionDown)
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            // Brief pause
            try? await Task.sleep(nanoseconds: 100_000_000)

            // 4 more rapid notification bursts
            for _ in 0..<4 {
                device.play(.notification)
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
            }

            // Final strong stop + success combo
            try? await Task.sleep(nanoseconds: 150_000_000)
            device.play(.stop)
            try? await Task.sleep(nanoseconds: 100_000_000)
            device.play(.success)
            try? await Task.sleep(nanoseconds: 100_000_000)
            device.play(.success)
        }
    }
}

#Preview {
    ContentView()
}
