//
//  WelcomeBackView.swift
//  JustWalk
//
//  Shown to returning users (reinstall) who need to re-authorize HealthKit
//

import SwiftUI
import HealthKit

struct WelcomeBackView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onComplete: () -> Void

    @State private var isRequestingHealth = false
    @State private var healthGranted = false
    @State private var showError = false

    // Animation states
    @State private var waveRotation: Double = 0
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showGreeting = false
    @State private var showRestoredCard = false
    @State private var showHealthSection = false
    @State private var showSkipButton = false
    @State private var cardItemsVisible: [Bool] = [false, false, false]

    private var streakManager: StreakManager { StreakManager.shared }
    private var shieldManager: ShieldManager { ShieldManager.shared }

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: JW.Spacing.xxl) {
                Spacer()

                // Welcome back header with animated wave
                VStack(spacing: JW.Spacing.lg) {
                    // Animated waving hand
                    ZStack {
                        Circle()
                            .fill(JW.Color.accent.opacity(0.15))
                            .frame(width: 90, height: 90)
                            .blur(radius: 15)
                            .opacity(showIcon ? 1 : 0)

                        Image(systemName: "hand.wave.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(JW.Color.accent)
                            .rotationEffect(.degrees(waveRotation), anchor: .bottomTrailing)
                    }
                    .scaleEffect(showIcon ? 1 : 0.5)
                    .opacity(showIcon ? 1 : 0)

                    Text("Welcome Back!")
                        .font(JW.Font.largeTitle)
                        .foregroundStyle(JW.Color.textPrimary)
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 20)

                    if !appState.profile.displayName.isEmpty {
                        Text("Good to see you again, \(appState.profile.displayName).")
                            .font(JW.Font.body)
                            .foregroundStyle(JW.Color.textSecondary)
                            .opacity(showGreeting ? 1 : 0)
                            .offset(y: showGreeting ? 0 : 15)
                    }
                }

                // Restored data summary card
                VStack(spacing: JW.Spacing.lg) {
                    Text("Your data has been restored")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)

                    HStack(spacing: JW.Spacing.xl) {
                        restoredDataItem(
                            icon: "flame.fill",
                            color: JW.Color.streak,
                            value: "\(streakManager.streakData.currentStreak)",
                            label: "day streak",
                            isVisible: cardItemsVisible[0]
                        )

                        restoredDataItem(
                            icon: "shield.fill",
                            color: JW.Color.accentBlue,
                            value: "\(shieldManager.shieldData.availableShields)",
                            label: "shields",
                            isVisible: cardItemsVisible[1]
                        )

                        restoredDataItem(
                            icon: "figure.walk",
                            color: JW.Color.accent,
                            value: "\(walkCount)",
                            label: "walks",
                            isVisible: cardItemsVisible[2]
                        )
                    }
                }
                .padding(.vertical, JW.Spacing.xl)
                .padding(.horizontal, JW.Spacing.lg)
                .background(JW.Color.backgroundCard)
                .cornerRadius(JW.Radius.lg)
                .padding(.horizontal, JW.Spacing.xl)
                .opacity(showRestoredCard ? 1 : 0)
                .offset(y: showRestoredCard ? 0 : 20)

                Spacer()

                // HealthKit permission section
                VStack(spacing: JW.Spacing.lg) {
                    Text("One more step")
                        .font(JW.Font.headline)
                        .foregroundStyle(JW.Color.textPrimary)

                    Text("Grant Health access to track your steps\nand continue your streak.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        JustWalkHaptics.buttonTap()
                        requestHealthAccess()
                    } label: {
                        HStack(spacing: JW.Spacing.sm) {
                            if isRequestingHealth {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.black)
                            } else {
                                Image(systemName: "heart.fill")
                                Text("Connect Apple Health")
                            }
                        }
                        .font(JW.Font.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, JW.Spacing.lg)
                        .background(JW.Color.accent)
                        .cornerRadius(JW.Radius.lg)
                    }
                    .buttonPressEffect()
                    .disabled(isRequestingHealth)
                    .padding(.horizontal, JW.Spacing.xl)

                    // Skip button
                    Button {
                        JustWalkHaptics.buttonTap()
                        skipHealthAccess()
                    } label: {
                        Text("Skip for now")
                            .font(JW.Font.footnote)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                    .opacity(showSkipButton ? 1 : 0)
                    .padding(.top, JW.Spacing.sm)
                }
                .opacity(showHealthSection ? 1 : 0)
                .offset(y: showHealthSection ? 0 : 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { runEntrance() }
        .alert("Health Access Required", isPresented: $showError) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Skip", role: .cancel) {
                skipHealthAccess()
            }
        } message: {
            Text("Health access was denied. You can enable it in Settings to track your steps.")
        }
    }

    private var walkCount: Int {
        PersistenceManager.shared.loadAllTrackedWalks().count
    }

    private func restoredDataItem(icon: String, color: Color, value: String, label: String, isVisible: Bool) -> some View {
        VStack(spacing: JW.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(JW.Font.title2)
                .fontWeight(.bold)
                .foregroundStyle(JW.Color.textPrimary)

            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        // Icon appears with spring
        withAnimation(.spring(response: quick ? 0.3 : 0.5, dampingFraction: 0.7).delay(quick ? 0 : 0.1)) {
            showIcon = true
        }

        // Wave animation (if not reduced motion)
        if !quick {
            startWaveAnimation()
        }

        // Headline
        withAnimation(.easeOut(duration: quick ? 0.2 : 0.5).delay(quick ? 0.1 : 0.3)) {
            showHeadline = true
        }

        // Greeting (if name exists)
        withAnimation(.easeOut(duration: quick ? 0.2 : 0.4).delay(quick ? 0.15 : 0.5)) {
            showGreeting = true
        }

        // Restored data card
        withAnimation(.easeOut(duration: quick ? 0.2 : 0.5).delay(quick ? 0.2 : 0.7)) {
            showRestoredCard = true
        }

        // Stagger card items
        for i in 0..<3 {
            withAnimation(.spring(response: quick ? 0.2 : 0.4, dampingFraction: 0.7).delay(quick ? 0.25 : 0.9 + Double(i) * 0.1)) {
                cardItemsVisible[i] = true
            }
        }

        // Health section
        withAnimation(.easeOut(duration: quick ? 0.2 : 0.5).delay(quick ? 0.3 : 1.3)) {
            showHealthSection = true
        }

        // Skip button (slightly after main button)
        withAnimation(.easeOut(duration: quick ? 0.2 : 0.4).delay(quick ? 0.35 : 1.6)) {
            showSkipButton = true
        }

        // Success haptic when card items appear
        DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0.3 : 1.0)) {
            JustWalkHaptics.selectionChanged()
        }
    }

    private func startWaveAnimation() {
        // Initial wave sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.15)) {
                waveRotation = 15
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeInOut(duration: 0.15)) {
                waveRotation = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.15)) {
                waveRotation = 12
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeInOut(duration: 0.15)) {
                waveRotation = -8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.2)) {
                waveRotation = 0
            }
        }
    }

    private func requestHealthAccess() {
        isRequestingHealth = true

        Task {
            let authorized = await HealthKitManager.shared.requestAuthorization()

            await MainActor.run {
                isRequestingHealth = false

                if authorized {
                    healthGranted = true
                    JustWalkHaptics.success()
                    // Sync HealthKit history with restored goal
                    Task {
                        let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
                        _ = await HealthKitManager.shared.syncHealthKitHistory(
                            days: HealthKitManager.historySyncDays,
                            dailyGoal: goal
                        )
                        await checkNotificationsAndComplete()
                    }
                } else {
                    showError = true
                }
            }
        }
    }

    private func skipHealthAccess() {
        // User chose to skip - they can enable later in Settings
        Task {
            await checkNotificationsAndComplete()
        }
    }

    /// Check if notifications are authorized, request if not, then complete
    private func checkNotificationsAndComplete() async {
        let notificationCenter = UNUserNotificationCenter.current()
        let settings = await notificationCenter.notificationSettings()

        // If notifications were previously granted (from original onboarding),
        // the CloudKit restore has NotificationManager.isEnabled = true,
        // but system authorization is lost on reinstall. Request it again.
        if settings.authorizationStatus == .notDetermined {
            // Request notification permission
            let granted = await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.isEnabled = granted
            WalkNotificationManager.shared.notificationsEnabled = granted
            if granted {
                WalkNotificationManager.shared.scheduleNotificationIfNeeded(force: true)
            }
        } else if settings.authorizationStatus == .denied {
            // User previously denied - keep NotificationManager.isEnabled as restored,
            // but the system will block notifications until they enable in Settings.
            // We could show a prompt here, but for now just continue.
        }

        await MainActor.run {
            onComplete()
        }
    }
}

#Preview {
    WelcomeBackView(onComplete: {})
        .environment(AppState())
}
