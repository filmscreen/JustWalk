//
//  CloudKitSyncFailedView.swift
//  JustWalk
//
//  Shown when CloudKit sync fails for returning users.
//  Offers retry option with escalating messaging after multiple attempts.
//

import SwiftUI

struct CloudKitSyncFailedView: View {
    let retryCount: Int
    let onRetry: () -> Void
    let onProceedAsNew: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation states
    @State private var showIcon = false
    @State private var glowActive = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showRetryButton = false
    @State private var showStartFreshButton = false
    @State private var showWarning = false
    @State private var isRetrying = false

    /// After this many retries, emphasize "Start Fresh" more strongly
    private let escalationThreshold = 2

    private var hasEscalated: Bool {
        retryCount >= escalationThreshold
    }

    var body: some View {
        ZStack {
            // Background - matches onboarding design
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: JW.Spacing.xxl) {
                Spacer()

                // Cloud error icon with pulsing glow
                ZStack {
                    Circle()
                        .fill(JW.Color.streak.opacity(glowActive ? 0.15 : 0))
                        .frame(width: 130, height: 130)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: glowActive
                        )

                    Image(systemName: "icloud.slash.fill")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(JW.Color.streak)
                }
                .opacity(showIcon ? 1 : 0)
                .scaleEffect(showIcon ? 1 : 0.5)

                // Copy - changes based on retry count
                VStack(spacing: JW.Spacing.lg) {
                    Text(headlineText)
                        .font(JW.Font.title1)
                        .foregroundStyle(JW.Color.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 20)

                    Text(bodyText)
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, JW.Spacing.xl)
                        .opacity(showBody ? 1 : 0)
                        .offset(y: showBody ? 0 : 15)
                }

                Spacer()

                // Buttons - order/emphasis changes after escalation
                VStack(spacing: JW.Spacing.lg) {
                    if hasEscalated {
                        // After multiple failures, emphasize Start Fresh
                        startFreshButton(isPrimary: true)
                            .opacity(showStartFreshButton ? 1 : 0)
                            .offset(y: showStartFreshButton ? 0 : 20)

                        retryButton(isPrimary: false)
                            .opacity(showRetryButton ? 1 : 0)
                    } else {
                        // First attempts: emphasize Retry
                        retryButton(isPrimary: true)
                            .opacity(showRetryButton ? 1 : 0)
                            .offset(y: showRetryButton ? 0 : 20)

                        startFreshButton(isPrimary: false)
                            .opacity(showStartFreshButton ? 1 : 0)
                    }

                    // Warning text
                    Text(warningText)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, JW.Spacing.xl)
                        .opacity(showWarning ? 1 : 0)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { runEntrance() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Dynamic Text

    private var headlineText: String {
        if hasEscalated {
            return "Still Having Trouble"
        } else {
            return "Sync Issue"
        }
    }

    private var bodyText: String {
        if hasEscalated {
            return "We've tried \(retryCount + 1) times but couldn't restore your data. You can keep trying, or start fresh with a new streak."
        } else if retryCount == 1 {
            return "Still couldn't connect. This is usually a temporary network issue — try again in a moment."
        } else {
            return "We couldn't restore your data from iCloud. This is usually a temporary network issue."
        }
    }

    private var warningText: String {
        if hasEscalated {
            return "Starting fresh means your previous streak,\nshields, and walk history won't be restored."
        } else {
            return "Your data is safely stored in iCloud.\nTry again when you have a stable connection."
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private func retryButton(isPrimary: Bool) -> some View {
        Button {
            JustWalkHaptics.buttonTap()
            isRetrying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onRetry()
            }
        } label: {
            HStack(spacing: JW.Spacing.sm) {
                if isRetrying {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isPrimary ? .black : JW.Color.textSecondary)
                } else {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
            }
            .font(JW.Font.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isPrimary ? JW.Color.accent : Color.clear)
            .foregroundStyle(isPrimary ? .black : JW.Color.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
        }
        .buttonPressEffect()
        .disabled(isRetrying)
        .padding(.horizontal, JW.Spacing.xl)
    }

    @ViewBuilder
    private func startFreshButton(isPrimary: Bool) -> some View {
        Button {
            JustWalkHaptics.buttonTap()
            onProceedAsNew()
        } label: {
            Text("Start Fresh")
                .font(isPrimary ? JW.Font.headline : JW.Font.subheadline)
                .frame(maxWidth: isPrimary ? .infinity : nil)
                .padding(isPrimary ? 16 : 0)
                .background(isPrimary ? JW.Color.accent : Color.clear)
                .foregroundStyle(isPrimary ? .black : JW.Color.textSecondary)
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
        }
        .buttonPressEffect()
        .disabled(isRetrying)
        .padding(.horizontal, isPrimary ? JW.Spacing.xl : 0)
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick
            ? Animation.easeOut(duration: 0.2)
            : .spring(response: 0.5, dampingFraction: 0.6)

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showIcon = true }
        if !quick { withAnimation(.easeInOut(duration: 1.5).delay(0.5)) { glowActive = true } }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.4)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.6)) { showBody = true }

        if hasEscalated {
            // Escalated: show Start Fresh first
            withAnimation(spring.delay(quick ? 0 : 0.9)) { showStartFreshButton = true }
            withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.1)) { showRetryButton = true }
        } else {
            // Normal: show Retry first
            withAnimation(spring.delay(quick ? 0 : 0.9)) { showRetryButton = true }
            withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.1)) { showStartFreshButton = true }
        }

        withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.3)) { showWarning = true }

        // Error haptic on appear
        DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0.1 : 0.3)) {
            JustWalkHaptics.error()
        }
    }
}

#Preview("First Attempt") {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        CloudKitSyncFailedView(
            retryCount: 0,
            onRetry: {},
            onProceedAsNew: {}
        )
    }
}

#Preview("After Multiple Retries") {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        CloudKitSyncFailedView(
            retryCount: 3,
            onRetry: {},
            onProceedAsNew: {}
        )
    }
}
