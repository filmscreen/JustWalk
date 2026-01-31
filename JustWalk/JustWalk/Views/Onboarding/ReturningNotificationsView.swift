//
//  ReturningNotificationsView.swift
//  JustWalk
//
//  Notification re-authorization screen for returning users.
//  Matches the design language of NotificationSetupView from onboarding.
//

import SwiftUI

struct ReturningNotificationsView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var notificationManager: NotificationManager { NotificationManager.shared }

    @State private var hasAdvanced = false

    // Entrance animation
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Bell icon in accent circular background
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }
            .scaleEffect(showIcon ? 1 : 0.8)
            .opacity(showIcon ? 1 : 0)

            // Copy
            VStack(spacing: JW.Spacing.md) {
                Text("Stay on Track")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                Text("Get reminders to hit your goal, plus\nlive coaching during guided walks.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showBody ? 1 : 0)
                    .offset(y: showBody ? 0 : 20)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            // Turn On Notifications button
            VStack(spacing: JW.Spacing.lg) {
                Button(action: handleTurnOn) {
                    Text("Turn On Notifications")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                // Skip button
                Button(action: handleSkip) {
                    Text("No thanks, skip")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(.horizontal, JW.Spacing.xl)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
            .padding(.bottom, 40)
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Actions

    private func handleTurnOn() {
        JustWalkHaptics.buttonTap()

        Task {
            let granted = await notificationManager.requestAuthorization()
            notificationManager.isEnabled = granted
            WalkNotificationManager.shared.notificationsEnabled = granted
            WalkNotificationManager.shared.scheduleNotificationIfNeeded(force: true)
            if granted {
                JustWalkHaptics.success()
            }
            advance()
        }
    }

    private func handleSkip() {
        JustWalkHaptics.buttonTap()
        notificationManager.isEnabled = false
        WalkNotificationManager.shared.notificationsEnabled = false
        WalkNotificationManager.shared.cancelPendingNotifications()
        advance()
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
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.9)) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        ReturningNotificationsView(onContinue: {})
    }
}
