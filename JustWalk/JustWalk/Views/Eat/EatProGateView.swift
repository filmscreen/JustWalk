//
//  EatProGateView.swift
//  JustWalk
//
//  Upsell view for free users to unlock the Eat tab with Pro
//

import SwiftUI

struct EatProGateView: View {
    @State private var showProUpgrade = false

    // Entrance animation states
    @State private var showHero = false
    @State private var showFeatures = false
    @State private var showCTA = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: JW.Spacing.xxl) {
                Spacer()
                    .frame(height: JW.Spacing.xl)

                // Hero section
                heroSection
                    .opacity(showHero ? 1 : 0)
                    .offset(y: showHero ? 0 : 20)

                // Feature highlights
                featureSection
                    .opacity(showFeatures ? 1 : 0)
                    .offset(y: showFeatures ? 0 : 15)

                // CTA button
                ctaSection
                    .opacity(showCTA ? 1 : 0)
                    .offset(y: showCTA ? 0 : 10)

                Spacer()
            }
            .padding(.horizontal, JW.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(JW.Color.backgroundPrimary)
        .onAppear { runEntrance() }
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView(onComplete: {})
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: JW.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "fork.knife")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }

            // Title
            Text("See the full picture")
                .font(JW.Font.largeTitle)
                .foregroundStyle(JW.Color.textPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text("Log what you eat with AI.\nNo scanning. No searching.")
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature Section

    private var featureSection: some View {
        VStack(spacing: JW.Spacing.md) {
            FeatureRow(
                icon: "sparkles",
                iconColor: JW.Color.accent,
                title: "AI-Powered Logging",
                description: "Just describe what you ate — we handle the rest"
            )

            FeatureRow(
                icon: "chart.pie.fill",
                iconColor: JW.Color.accentBlue,
                title: "Track Your Macros",
                description: "See calories, protein, carbs, and fat at a glance"
            )

            FeatureRow(
                icon: "calendar",
                iconColor: JW.Color.accentPurple,
                title: "Daily History",
                description: "Review what you've eaten any day this week"
            )

            FeatureRow(
                icon: "figure.walk",
                iconColor: JW.Color.streak,
                title: "Walk + Eat Together",
                description: "Complete picture of your daily health habits"
            )
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
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
        .padding(.top, JW.Spacing.lg)
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.1)) {
            showHero = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.3)) {
            showFeatures = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) {
            showCTA = true
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: JW.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                Text(title)
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text(description)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview {
    EatProGateView()
}
