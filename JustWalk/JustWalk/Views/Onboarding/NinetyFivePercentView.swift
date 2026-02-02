//
//  NinetyFivePercentView.swift
//  JustWalk
//
//  Screen 2: "Two habits. 95% of your well-being." — positioning the app's focus
//

import SwiftUI

struct NinetyFivePercentView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showGraphic = false
    @State private var showHeadline = false
    @State private var showBreakdown = false
    @State private var showPunchline = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Visual breakdown graphic
            breakdownGraphic
                .opacity(showGraphic ? 1 : 0)
                .scaleEffect(showGraphic ? 1 : 0.9)

            // Copy section
            VStack(spacing: JW.Spacing.lg) {
                // Headline
                Text("Two habits.\n95% of your well-being.")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                // Breakdown explanation
                VStack(spacing: JW.Spacing.sm) {
                    breakdownRow(icon: "fork.knife", text: "What you eat", percentage: "75-80%", color: JW.Color.accent)
                    breakdownRow(icon: "figure.walk", text: "Daily walking", percentage: "15-20%", color: JW.Color.accentBlue)
                }
                .opacity(showBreakdown ? 1 : 0)
                .offset(y: showBreakdown ? 0 : 20)

                // Punchline
                Text("Formal exercise? Just 5%.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textTertiary)
                    .opacity(showPunchline ? 1 : 0)
                    .offset(y: showPunchline ? 0 : 10)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

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
        .onAppear { runEntrance() }
    }

    // MARK: - Breakdown Graphic

    private var breakdownGraphic: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 12)
                .frame(width: 160, height: 160)

            // Diet segment (75-80%) - accent color
            Circle()
                .trim(from: 0, to: showGraphic ? 0.775 : 0)
                .stroke(JW.Color.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Walking segment (15-20%) - blue
            Circle()
                .trim(from: 0.775, to: showGraphic ? 0.95 : 0.775)
                .stroke(JW.Color.accentBlue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Exercise segment (5%) - subtle
            Circle()
                .trim(from: 0.95, to: showGraphic ? 1.0 : 0.95)
                .stroke(JW.Color.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 2) {
                Text("95")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(JW.Color.textPrimary)
                Text("%")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(JW.Color.textSecondary)
            }
        }
    }

    // MARK: - Breakdown Row

    private func breakdownRow(icon: String, text: String, percentage: String, color: Color) -> some View {
        HStack(spacing: JW.Spacing.md) {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 24)

            // Text
            Text(text)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer()

            // Percentage
            Text(percentage)
                .font(JW.Font.headline)
                .foregroundStyle(color)
        }
        .padding(.horizontal, JW.Spacing.lg)
        .padding(.vertical, JW.Spacing.sm)
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick
            ? Animation.easeOut(duration: 0.2)
            : .spring(response: 0.6, dampingFraction: 0.7)

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showGraphic = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.6)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.9)) { showBreakdown = true }
        withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.2)) { showPunchline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.4)) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        NinetyFivePercentView(onContinue: {})
    }
}
