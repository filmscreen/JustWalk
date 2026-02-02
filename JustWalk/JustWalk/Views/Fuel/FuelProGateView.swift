//
//  FuelProGateView.swift
//  JustWalk
//
//  Upsell view for free users to unlock the Fuel tab with Pro
//

import SwiftUI

struct FuelProGateView: View {
    @State private var showProUpgrade = false

    // Entrance animation states
    @State private var showContent = false
    @State private var showRing = false
    @State private var showCTA = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Main content - centered vertically
            VStack(spacing: JW.Spacing.xl) {
                // Animated 95% ring graphic
                wellbeingRing
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.8)

                // Title and messages
                VStack(spacing: JW.Spacing.lg) {
                    // Title
                    Text("See the full picture.")
                        .font(JW.Font.largeTitle)
                        .foregroundStyle(JW.Color.textPrimary)
                        .multilineTextAlignment(.center)

                    // Core message
                    Text("Walking is ~20% of your well-being.\nWhat you eat is the other ~75%.")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)

                    // Value proposition
                    Text("Track your calories and macros in seconds — just describe what you ate.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, JW.Spacing.md)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            // CTA section - pinned toward bottom
            VStack(spacing: JW.Spacing.md) {
                Button {
                    JustWalkHaptics.buttonTap()
                    showProUpgrade = true
                } label: {
                    Text("Unlock with Pro")
                        .font(JW.Font.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(JW.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                Text("7-day free trial included")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, JW.Spacing.xxl)
            .opacity(showCTA ? 1 : 0)
            .offset(y: showCTA ? 0 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(JW.Color.backgroundPrimary)
        .onAppear { runEntrance() }
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView(onComplete: {})
        }
    }

    // MARK: - 95% Wellbeing Ring

    private var wellbeingRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 10)
                .frame(width: 120, height: 120)

            // Food segment (~75%) - teal/accent, starts at top
            Circle()
                .trim(from: 0, to: showRing ? 0.775 : 0)
                .stroke(JW.Color.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            // Walking segment (~20%) - blue, continues from food
            Circle()
                .trim(from: 0.775, to: showRing ? 0.95 : 0.775)
                .stroke(JW.Color.accentBlue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            // Center: 95%
            VStack(spacing: 0) {
                Text("95")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(JW.Color.textPrimary)
                Text("%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(JW.Color.textSecondary)
            }
        }
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.1)) {
            showContent = true
        }

        // Animate ring segments with spring
        let ringAnimation = quick
            ? Animation.easeOut(duration: 0.3)
            : .spring(response: 0.8, dampingFraction: 0.7)
        withAnimation(ringAnimation.delay(quick ? 0 : 0.2)) {
            showRing = true
        }

        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) {
            showCTA = true
        }
    }
}

// MARK: - Previews

#Preview {
    FuelProGateView()
}
