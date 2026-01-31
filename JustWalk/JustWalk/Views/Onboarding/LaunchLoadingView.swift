//
//  LaunchLoadingView.swift
//  JustWalk
//
//  Elegant loading screen with animated progress ring shown while checking CloudKit data
//

import SwiftUI

struct LaunchLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation states
    @State private var showContent = false
    @State private var ringRotation: Double = 0
    @State private var ringProgress: CGFloat = 0
    @State private var glowOpacity: CGFloat = 0.3
    @State private var iconBounce: CGFloat = 0

    // Ring configuration
    private let ringSize: CGFloat = 120
    private let ringLineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: JW.Spacing.xxl) {
                Spacer()

                // Animated ring with walking figure
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(JW.Color.accent.opacity(glowOpacity * 0.5))
                        .frame(width: ringSize + 40, height: ringSize + 40)
                        .blur(radius: 25)

                    // Background ring (subtle track)
                    Circle()
                        .stroke(JW.Color.accent.opacity(0.15), lineWidth: ringLineWidth)
                        .frame(width: ringSize, height: ringSize)

                    // Animated progress ring
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    JW.Color.accent.opacity(0.3),
                                    JW.Color.accent,
                                    JW.Color.accent
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90 + ringRotation))

                    // Walking figure in center
                    Image(systemName: "figure.walk")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(JW.Color.accent)
                        .offset(y: iconBounce)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)

                // App name
                Text("Just Walk")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 15)

                Spacer()

                // Subtle status text
                Text("Preparing your experience")
                    .font(JW.Font.footnote)
                    .foregroundStyle(JW.Color.textTertiary)
                    .opacity(showContent ? 0.8 : 0)
                    .padding(.bottom, 60)
            }
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Animations

    private func runEntrance() {
        let quick = reduceMotion

        // Content appears
        withAnimation(.spring(response: quick ? 0.3 : 0.6, dampingFraction: 0.8).delay(quick ? 0 : 0.1)) {
            showContent = true
        }

        guard !quick else { return }

        // Start ring rotation (continuous spin)
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Ring progress fills and resets in a loop
        startProgressLoop()

        // Glow pulses
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.3)) {
            glowOpacity = 0.6
        }

        // Walking figure subtle bounce
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.5)) {
            iconBounce = -4
        }
    }

    private func startProgressLoop() {
        // Fill to ~75% then reset, creating a smooth looping effect
        withAnimation(.easeInOut(duration: 1.5)) {
            ringProgress = 0.75
        }

        // Reset and repeat
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                ringProgress = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                startProgressLoop()
            }
        }
    }
}

#Preview {
    LaunchLoadingView()
}
