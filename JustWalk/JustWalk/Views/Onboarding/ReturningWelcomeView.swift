//
//  ReturningWelcomeView.swift
//  JustWalk
//
//  First screen of returning user flow showing restored data summary.
//  Features animated waving hand icon and restored data card.
//

import SwiftUI

struct ReturningWelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    // Animation states
    @State private var waveRotation: Double = 0
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showGreeting = false
    @State private var showRestoredCard = false
    @State private var cardItemsVisible: [Bool] = [false, false, false]
    @State private var showButton = false

    private var streakManager: StreakManager { StreakManager.shared }
    private var shieldManager: ShieldManager { ShieldManager.shared }

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Welcome back header with animated wave
            VStack(spacing: JW.Spacing.lg) {
                // Animated waving hand
                ZStack {
                    Circle()
                        .fill(JW.Color.accent.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(JW.Color.accent)
                        .rotationEffect(.degrees(waveRotation), anchor: .bottomTrailing)
                }
                .scaleEffect(showIcon ? 1 : 0.8)
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

            // Continue button
            Button(action: handleContinue) {
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

    // MARK: - Actions

    private func handleContinue() {
        JustWalkHaptics.buttonTap()
        onContinue()
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

        // Continue button
        withAnimation(.easeOut(duration: quick ? 0.2 : 0.5).delay(quick ? 0.35 : 1.3)) {
            showButton = true
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
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        ReturningWelcomeView(onContinue: {})
            .environment(AppState())
    }
}
