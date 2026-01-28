//
//  TealConfettiBurst.swift
//  Just Walk
//
//  Small teal confetti burst (15-20 particles) for challenge completion.
//  Respects Reduce Motion accessibility setting.
//

import SwiftUI

struct TealConfettiBurst: View {
    @State private var animate = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        if accessibility.reduceMotionEnabled {
            // Reduce Motion: No animated confetti, toast content is enough
            EmptyView()
        } else {
            animatedConfetti
        }
    }

    // MARK: - Animated Confetti

    @ViewBuilder
    private var animatedConfetti: some View {
        ZStack {
            ForEach(0..<18) { i in
                TealConfettiParticle(animate: $animate, index: i)
            }
        }
        .onAppear {
            animate = true
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Teal Confetti Particle

struct TealConfettiParticle: View {
    @Binding var animate: Bool
    let index: Int

    @State private var xOffset: CGFloat = 0
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    private let particleSize: CGFloat = 6
    private let color: Color

    init(animate: Binding<Bool>, index: Int) {
        self._animate = animate
        self.index = index
        self.color = Self.tealColors.randomElement() ?? Color(hex: "00C7BE")
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: particleSize, height: particleSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: xOffset, y: yOffset)
            .rotationEffect(.degrees(rotation))
            .onChange(of: animate) { _, newValue in
                if newValue {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        // Random angle for burst direction (full circle)
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: 40...100)

        // Calculate final position based on angle
        let finalX = cos(angle) * distance
        let finalY = sin(angle) * distance - 20 // Slight upward bias

        // Stagger start times slightly for organic feel
        let delay = Double.random(in: 0...0.1)

        withAnimation(
            .easeOut(duration: 1.2)
            .delay(delay)
        ) {
            xOffset = finalX
            yOffset = finalY
            rotation = Double.random(in: 180...540)
            scale = CGFloat.random(in: 0.3...0.6)
        }

        // Fade out near end
        withAnimation(
            .easeIn(duration: 0.4)
            .delay(delay + 0.8)
        ) {
            opacity = 0
        }
    }

    // MARK: - Teal Color Palette

    static var tealColors: [Color] {
        [
            Color(hex: "00C7BE"),        // Primary teal
            Color(hex: "00D4C8"),        // Lighter teal
            Color(hex: "00B5A9"),        // Darker teal
            Color(hex: "40D9D1"),        // Bright teal
            Color(hex: "009E94"),        // Deep teal
            Color(hex: "7EEEE6")         // Pale teal
        ]
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.3)

        VStack {
            Text("Confetti Test")
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay {
                    TealConfettiBurst()
                }
        }
    }
}
