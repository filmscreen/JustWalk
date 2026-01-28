//
//  ConfettiView.swift
//  Just Walk
//
//  Celebration confetti with Reduce Motion accessibility support.
//

import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        if accessibility.reduceMotionEnabled {
            // Reduce Motion: Static celebration emoji instead of animated confetti
            staticCelebration
        } else {
            // Full animation experience
            animatedConfetti
        }
    }

    // MARK: - Reduce Motion Alternative

    @ViewBuilder
    private var staticCelebration: some View {
        VStack {
            Text("🎉")
                .font(.system(size: 80))
                .accessibilityHidden(true) // Decorative
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
    }

    // MARK: - Animated Confetti

    @ViewBuilder
    private var animatedConfetti: some View {
        ZStack {
            ForEach(0..<50) { i in
                ConfettiParticle(animate: $animate, index: i)
            }
        }
        .onAppear {
            animate = true
        }
        .accessibilityHidden(true) // Decorative animation
    }
}

struct ConfettiParticle: View {
    @Binding var animate: Bool
    let index: Int
    
    @State private var xPosition: CGFloat = 0
    @State private var yPosition: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var color: Color = .random
    
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 8)
                .position(x: xPosition, y: yPosition)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                   reset(in: geometry.size)
                }
                .onChange(of: animate) { _, newValue in
                    if newValue {
                        withAnimation(.easeOut(duration: Double.random(in: 2.0...4.0))) {
                            yPosition = geometry.size.height + 50
                            rotation += Double.random(in: 180...720)
                            xPosition += CGFloat.random(in: -50...50)
                        }
                    }
                }
        }
        .allowsHitTesting(false)
    }
    
    private func reset(in size: CGSize) {
        xPosition = CGFloat.random(in: 0...size.width)
        yPosition = -CGFloat.random(in: 0...100) // Start above screen
        rotation = Double.random(in: 0...360)
        color = .random
    }
}

extension Color {
    /// Curated celebration palette for premium confetti
    static var celebrationColors: [Color] {
        [
            Color(red: 1.0, green: 0.84, blue: 0.0),    // Gold
            Color(red: 1.0, green: 0.6, blue: 0.2),     // Orange
            Color(red: 1.0, green: 0.4, blue: 0.4),     // Coral
            Color(red: 0.4, green: 0.9, blue: 0.6),     // Mint
            Color(red: 0.4, green: 0.7, blue: 1.0),     // Sky Blue
            Color(red: 0.7, green: 0.5, blue: 1.0),     // Violet
            Color(red: 1.0, green: 0.75, blue: 0.8)     // Pink
        ]
    }
    
    static var random: Color {
        celebrationColors.randomElement() ?? .yellow
    }
}

