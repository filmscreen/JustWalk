//
//  PermissionsView.swift
//  JustWalk
//
//  Screen 5: Health & Motion access — "One Quick Thing."
//

import SwiftUI
import CoreMotion

struct PermissionsView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var healthAuthorized = false
    @State private var permissionDenied = false
    @State private var hasAdvanced = false
    @State private var isRequesting = false

    // Entrance animation
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Health icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.green)
            }
            .scaleEffect(showIcon ? 1 : 0.8)
            .opacity(showIcon ? 1 : 0)

            // Copy
            VStack(spacing: JW.Spacing.md) {
                Text("One Quick Thing.")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                Text("Just Walk needs access to health data and\nmotion sensors to track your steps.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showBody ? 1 : 0)
                    .offset(y: showBody ? 0 : 20)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            // Action button — state-driven label
            Button(action: { handleButtonTap() }) {
                Group {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(buttonTitle)
                            .contentTransition(.interpolate)
                    }
                }
                .font(JW.Font.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(JW.Color.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .disabled(isRequesting)
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)

            // Trust message
            Text("We read steps, workouts, and motion data.\nWe never share your data.")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 40)
                .opacity(showButton ? 1 : 0)
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
        if healthAuthorized {
            return "Continue"
        } else if permissionDenied {
            return "Open Settings"
        } else {
            return "Allow Access"
        }
    }

    // MARK: - Actions

    private func checkExistingAuthorization() {
        Task {
            let alreadyAuthorized = await HealthKitManager.shared.isCurrentlyAuthorized()
            if alreadyAuthorized {
                healthAuthorized = true
            }
        }
    }

    private func handleButtonTap() {
        JustWalkHaptics.buttonTap()

        if healthAuthorized {
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

    private func requestPermissions() {
        isRequesting = true
        Task {
            // Step 1: Request HealthKit
            print("[Onboarding] Requesting HealthKit authorization...")
            let healthGranted = await HealthKitManager.shared.requestAuthorization()
            print("[Onboarding] HealthKit authorization result: \(healthGranted)")

            // Step 2: Request Core Motion (regardless of HealthKit result)
            print("[Onboarding] Requesting Motion authorization...")
            let motionGranted = await requestMotionPermission()
            print("[Onboarding] Motion authorization result: \(motionGranted)")

            // Step 3: Advance regardless of individual results
            isRequesting = false
            if healthGranted {
                withAnimation { healthAuthorized = true }
                JustWalkHaptics.success()
                try? await Task.sleep(for: .milliseconds(500))
                advance()
            } else {
                withAnimation { permissionDenied = true }
            }
        }
    }

    /// Triggers the Core Motion permission dialog by querying the pedometer.
    private func requestMotionPermission() async -> Bool {
        #if targetEnvironment(simulator)
        // CMPedometer is unavailable on the simulator
        print("[Onboarding] Simulator detected — skipping motion permission")
        return true
        #else
        guard CMPedometer.isStepCountingAvailable() else {
            print("[Onboarding] Step counting not available on this device")
            return false
        }

        let pedometer = CMPedometer()
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: oneHourAgo, to: now) { _, error in
                if let error {
                    print("[Onboarding] Motion permission error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else {
                    print("[Onboarding] Motion permission granted")
                    continuation.resume(returning: true)
                }
            }
        }
        #endif
    }

    private func recheckAuthorization() {
        guard permissionDenied, !hasAdvanced else { return }
        Task {
            let granted = await HealthKitManager.shared.requestAuthorization()
            if granted {
                withAnimation { healthAuthorized = true }
                JustWalkHaptics.success()
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
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.0)) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        PermissionsView(onContinue: {})
    }
}
