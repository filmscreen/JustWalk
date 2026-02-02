//
//  StreakShieldsOnboardingView.swift
//  JustWalk
//
//  Screen 2: "Build Your Streak" — explains streaks and shields together
//

import SwiftUI

struct StreakShieldsOnboardingView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showWeekViz = false
    @State private var showSubtext = false
    @State private var showShieldsCard = false
    @State private var showButton = false

    var body: some View {
        ScrollView {
            VStack(spacing: JW.Spacing.xl) {
                Spacer(minLength: JW.Spacing.xxl)

                // Fire icon in circular background
                ZStack {
                    Circle()
                        .fill(JW.Color.streak.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Text("🔥")
                        .font(.system(size: 52))
                }
                .opacity(showIcon ? 1 : 0)
                .scaleEffect(showIcon ? 1 : 0.8)

                // Headline
                Text("Build Your Streak.")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                // Week visualization
                weekVisualization
                    .opacity(showWeekViz ? 1 : 0)
                    .scaleEffect(showWeekViz ? 1 : 0.95)

                // Subtext
                VStack(spacing: JW.Spacing.xs) {
                    Text("Hit your goal daily.")
                    Text("Build a streak.")
                    Text("Watch the days add up.")
                }
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(showSubtext ? 1 : 0)
                .offset(y: showSubtext ? 0 : 15)

                // Shields card
                shieldsCard
                    .padding(.horizontal, JW.Spacing.xl)
                    .opacity(showShieldsCard ? 1 : 0)
                    .scaleEffect(showShieldsCard ? 1 : 0.95)

                Spacer(minLength: JW.Spacing.xl)

                // Continue button
                Button(action: {
                    JustWalkHaptics.buttonTap()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.bottom, 40)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { runEntrance() }
    }

    // MARK: - Week Visualization

    private var weekVisualization: some View {
        let days = ["S", "M", "T", "W", "T", "F", "S"]
        let completedCount = 6 // First 6 days completed, last day (today) empty

        return VStack(spacing: JW.Spacing.sm) {
            HStack(spacing: JW.Spacing.md) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: JW.Spacing.xs) {
                        // Day circle
                        ZStack {
                            Circle()
                                .fill(index < completedCount ? JW.Color.accent : JW.Color.backgroundCard)
                                .frame(width: 36, height: 36)

                            if index < completedCount {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.black)
                            } else {
                                // Empty circle for "today"
                                Circle()
                                    .stroke(JW.Color.textTertiary, lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                        }

                        // Day label
                        Text(days[index])
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, JW.Spacing.md)
    }

    // MARK: - Shields Card

    private var shieldsCard: some View {
        VStack(spacing: JW.Spacing.md) {
            // Title row
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(JW.Color.accentBlue)

                Text("Life happens.")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Spacer()
            }

            // Body text
            Text("Shields protect your streak when you need a break.")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Gift row
            HStack(spacing: JW.Spacing.sm) {
                HStack(spacing: JW.Spacing.xs) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(JW.Color.accentBlue)
                    Image(systemName: "shield.fill")
                        .foregroundStyle(JW.Color.accentBlue)
                }
                .font(.system(size: 18))

                Text("Your first 2 are on us.")
                    .font(JW.Font.subheadline.weight(.medium))
                    .foregroundStyle(JW.Color.textPrimary)

                Spacer()
            }
            .padding(.top, JW.Spacing.xs)
        }
        .padding(JW.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: JW.Radius.lg)
                        .stroke(JW.Color.accentBlue.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick
            ? Animation.easeOut(duration: 0.2)
            : .spring(response: 0.5, dampingFraction: 0.7)

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showIcon = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) { showHeadline = true }
        withAnimation(spring.delay(quick ? 0 : 0.7)) { showWeekViz = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.9)) { showSubtext = true }
        withAnimation(spring.delay(quick ? 0 : 1.1)) {
            showShieldsCard = true
            if !quick { JustWalkHaptics.selectionChanged() }
        }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.4)) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        StreakShieldsOnboardingView(onContinue: {})
    }
}
