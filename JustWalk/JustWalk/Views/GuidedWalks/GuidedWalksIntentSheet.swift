//
//  GuidedWalksIntentSheet.swift
//  JustWalk
//
//  One-time intent sheet: "What brings you here?" for Guided Walks personalization
//

import SwiftUI

struct GuidedWalksIntentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("guidedWalksIntent") private var userIntent: String = "exploring"
    @AppStorage("hasSeenGuidedWalksIntent") private var hasSeenIntent: Bool = false

    // Entrance animation state
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showSubhead = false
    @State private var showCards = false
    @State private var showSkip = false

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: JW.Spacing.xl) {
                Spacer()
                    .frame(height: JW.Spacing.xxl)

                // Header icon
                ZStack {
                    Circle()
                        .fill(JW.Color.accent.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(JW.Color.accent)
                }
                .opacity(showIcon ? 1 : 0)
                .scaleEffect(showIcon ? 1 : 0.8)

                // Headline
                Text("What brings you here?")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                // Subhead
                Text("This helps us personalize your experience.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showSubhead ? 1 : 0)
                    .offset(y: showSubhead ? 0 : 15)

                // Intent cards
                VStack(spacing: JW.Spacing.md) {
                    IntentOptionCard(
                        icon: "timer",
                        iconColor: JW.Color.accent,
                        title: "Short on time",
                        subtitle: "Get more from every walk"
                    ) {
                        selectIntent("short_on_time")
                    }
                    .staggeredAppearance(index: 0, delay: 0.1)

                    IntentOptionCard(
                        icon: "flame.fill",
                        iconColor: JW.Color.streak,
                        title: "Burn fat",
                        subtitle: "Optimize walks for fat loss"
                    ) {
                        selectIntent("burn_fat")
                    }
                    .staggeredAppearance(index: 1, delay: 0.1)

                    IntentOptionCard(
                        icon: "dumbbell.fill",
                        iconColor: JW.Color.accentBlue,
                        title: "Build fitness",
                        subtitle: "Improve endurance over time"
                    ) {
                        selectIntent("build_fitness")
                    }
                    .staggeredAppearance(index: 2, delay: 0.1)

                    IntentOptionCard(
                        icon: "sparkles",
                        iconColor: JW.Color.accentPurple,
                        title: "Just exploring",
                        subtitle: "Show me everything"
                    ) {
                        selectIntent("exploring")
                    }
                    .staggeredAppearance(index: 3, delay: 0.1)
                }
                .padding(.horizontal, JW.Spacing.lg)
                .opacity(showCards ? 1 : 0)

                Spacer()

                // Skip
                Button(action: {
                    JustWalkHaptics.buttonTap()
                    hasSeenIntent = true
                    dismiss()
                }) {
                    Text("Skip")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
                .opacity(showSkip ? 1 : 0)
                .offset(y: showSkip ? 0 : 10)
                .padding(.bottom, JW.Spacing.xxl)
            }
        }
        .onAppear { runEntrance() }
        .interactiveDismissDisabled(false)
    }

    // MARK: - Actions

    private func selectIntent(_ intent: String) {
        JustWalkHaptics.buttonTap()
        userIntent = intent
        hasSeenIntent = true
        dismiss()
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick ? Animation.easeOut(duration: 0.2) : JustWalkAnimation.emphasis

        withAnimation(spring.delay(quick ? 0 : 0.3)) { showIcon = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.6)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.9)) { showSubhead = true }
        withAnimation(.easeOut(duration: 0.3).delay(quick ? 0 : 1.1)) { showCards = true }
        withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.8)) { showSkip = true }
    }
}

// MARK: - Intent Option Card

private struct IntentOptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: JW.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(JW.Font.headline)
                        .foregroundStyle(JW.Color.textPrimary)

                    Text(subtitle)
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }
            .padding(JW.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .buttonPressEffect()
    }
}

#Preview {
    GuidedWalksIntentSheet()
}
