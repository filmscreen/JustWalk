//
//  ReturningHealthView.swift
//  JustWalk
//
//  Health + Motion permissions screen for returning users.
//  Matches the design language of PermissionsView from onboarding.
//

import SwiftUI
import CoreMotion

struct ReturningHealthView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var healthAuthorized = false
    @State private var motionAuthorized = false
    @State private var permissionDenied = false
    @State private var hasAdvanced = false
    @State private var isRequesting = false

    // Entrance animation
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showStatus = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Heart icon in green circular background
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }
            .scaleEffect(showIcon ? 1 : 0.8)
            .opacity(showIcon ? 1 : 0)

            // Copy
            VStack(spacing: JW.Spacing.md) {
                Text("Reconnect Health")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                Text("Grant access to continue tracking your\nsteps and sync your activity.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showBody ? 1 : 0)
                    .offset(y: showBody ? 0 : 20)
            }
            .padding(.horizontal, JW.Spacing.xl)

            // Permission status indicators
            VStack(spacing: JW.Spacing.md) {
                permissionStatusRow(
                    icon: "heart.fill",
                    label: "Apple Health",
                    granted: healthAuthorized
                )

                permissionStatusRow(
                    icon: "figure.walk",
                    label: "Motion & Fitness",
                    granted: motionAuthorized
                )
            }
            .padding(.vertical, JW.Spacing.lg)
            .padding(.horizontal, JW.Spacing.xl)
            .background(JW.Color.backgroundCard)
            .cornerRadius(JW.Radius.lg)
            .padding(.horizontal, JW.Spacing.xl)
            .opacity(showStatus ? 1 : 0)
            .offset(y: showStatus ? 0 : 15)

            Spacer()

            // Action buttons
            VStack(spacing: JW.Spacing.lg) {
                Button(action: handleButtonTap) {
                    Group {
                        if isRequesting {
                            ProgressView()
                                .tint(.black)
                        } else {
                            HStack(spacing: JW.Spacing.sm) {
                                Image(systemName: "heart.fill")
                                Text(buttonTitle)
                            }
                        }
                    }
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .disabled(isRequesting)
                .buttonPressEffect()

                // Skip button
                Button(action: handleSkip) {
                    Text("Skip for now")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .onAppear {
            runEntrance()
            checkExistingAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                recheckAuthorization()
            }
        }
    }

    // MARK: - Button State

    private var buttonTitle: String {
        if healthAuthorized && motionAuthorized {
            return "Continue"
        } else if permissionDenied {
            return "Open Settings"
        } else {
            return "Connect Apple Health"
        }
    }

    // MARK: - Views

    private func permissionStatusRow(icon: String, label: String, granted: Bool) -> some View {
        HStack(spacing: JW.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(granted ? JW.Color.accent : JW.Color.textSecondary)
                .frame(width: 24)

            Text(label)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(JW.Color.success)
            } else {
                Circle()
                    .stroke(JW.Color.textTertiary, lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
        }
    }

    // MARK: - Actions

    private func checkExistingAuthorization() {
        Task {
            let health = await HealthKitManager.shared.isCurrentlyAuthorized()
            let motion = await checkMotionAuthorization()
            await MainActor.run {
                healthAuthorized = health
                motionAuthorized = motion
            }
        }
    }

    private func handleButtonTap() {
        JustWalkHaptics.buttonTap()

        if healthAuthorized && motionAuthorized {
            advance()
            return
        }

        if permissionDenied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
            return
        }

        guard !isRequesting else { return }
        requestPermissions()
    }

    private func handleSkip() {
        JustWalkHaptics.buttonTap()
        advance()
    }

    private func requestPermissions() {
        isRequesting = true
        Task {
            // Step 1: Request HealthKit
            let healthGranted = await HealthKitManager.shared.requestAuthorization()

            // Step 2: Request Core Motion
            let motionGranted = await requestMotionPermission()

            await MainActor.run {
                isRequesting = false
                healthAuthorized = healthGranted
                motionAuthorized = motionGranted

                if healthGranted {
                    JustWalkHaptics.success()

                    // Sync HealthKit history with restored goal
                    Task {
                        let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
                        _ = await HealthKitManager.shared.syncHealthKitHistory(
                            days: HealthKitManager.historySyncDays,
                            dailyGoal: goal
                        )
                    }

                    // Advance after a brief delay
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        advance()
                    }
                } else {
                    withAnimation { permissionDenied = true }
                }
            }
        }
    }

    private func requestMotionPermission() async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard CMPedometer.isStepCountingAvailable() else {
            return false
        }

        let pedometer = CMPedometer()
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: oneHourAgo, to: now) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
        #endif
    }

    private func checkMotionAuthorization() async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard CMPedometer.isStepCountingAvailable() else {
            return false
        }

        let pedometer = CMPedometer()
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: oneHourAgo, to: now) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
        #endif
    }

    private func recheckAuthorization() {
        guard permissionDenied, !hasAdvanced else { return }
        Task {
            let health = await HealthKitManager.shared.requestAuthorization()
            let motion = await checkMotionAuthorization()
            if health {
                await MainActor.run {
                    healthAuthorized = true
                    motionAuthorized = motion
                    JustWalkHaptics.success()
                }
                try? await Task.sleep(for: .milliseconds(500))
                advance()
            }
        }
    }

    private func advance() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        onContinue()
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick ? Animation.easeOut(duration: 0.2) : JustWalkAnimation.emphasis

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showIcon = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.7)) { showBody = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.9)) { showStatus = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.1)) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        ReturningHealthView(onContinue: {})
    }
}
