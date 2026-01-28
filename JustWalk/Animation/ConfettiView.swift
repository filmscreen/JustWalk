//
//  ConfettiView.swift
//  JustWalk
//
//  Particle-based confetti animation for celebrations
//

import SwiftUI

struct ConfettiView: View {
    @Binding var isActive: Bool

    let colors: [Color]
    let particleCount: Int
    let duration: Double

    @State private var particles: [ConfettiParticle] = []
    @State private var animationPhase = 0

    init(
        isActive: Binding<Bool>,
        colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink],
        particleCount: Int = 50,
        duration: Double = 2.0
    ) {
        self._isActive = isActive
        self.colors = colors
        self.particleCount = particleCount
        self.duration = duration
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiParticleView(
                        particle: particle,
                        animationPhase: animationPhase,
                        containerSize: geometry.size
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startConfetti()
            }
        }
    }

    private func startConfetti() {
        // Generate particles
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                color: colors.randomElement() ?? .blue,
                shape: ConfettiShape.allCases.randomElement() ?? .circle,
                size: CGFloat.random(in: 6...12),
                startX: CGFloat.random(in: 0.3...0.7),
                horizontalSpread: CGFloat.random(in: -0.4...0.4),
                rotationSpeed: Double.random(in: -720...720),
                delay: Double.random(in: 0...0.3)
            )
        }

        // Trigger animation
        withAnimation(.linear(duration: duration)) {
            animationPhase = 1
        }

        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.5) {
            animationPhase = 0
            particles = []
            isActive = false
        }
    }
}

// MARK: - Confetti Particle Model

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let shape: ConfettiShape
    let size: CGFloat
    let startX: CGFloat
    let horizontalSpread: CGFloat
    let rotationSpeed: Double
    let delay: Double
}

enum ConfettiShape: CaseIterable {
    case circle
    case rectangle
    case triangle
}

// MARK: - Confetti Particle View

struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    let animationPhase: Int
    let containerSize: CGSize

    var body: some View {
        shapeView
            .frame(width: particle.size, height: particle.size * aspectRatio)
            .rotationEffect(.degrees(rotation))
            .position(position)
            .opacity(opacity)
            .animation(
                .easeOut(duration: 2.0).delay(particle.delay),
                value: animationPhase
            )
    }

    @ViewBuilder
    private var shapeView: some View {
        switch particle.shape {
        case .circle:
            Circle().fill(particle.color)
        case .rectangle:
            Rectangle().fill(particle.color)
        case .triangle:
            Triangle().fill(particle.color)
        }
    }

    private var aspectRatio: CGFloat {
        switch particle.shape {
        case .circle: return 1.0
        case .rectangle: return 1.5
        case .triangle: return 1.2
        }
    }

    private var position: CGPoint {
        if animationPhase == 0 {
            return CGPoint(
                x: containerSize.width * particle.startX,
                y: -20
            )
        } else {
            return CGPoint(
                x: containerSize.width * (particle.startX + particle.horizontalSpread),
                y: containerSize.height + 50
            )
        }
    }

    private var rotation: Double {
        animationPhase == 0 ? 0 : particle.rotationSpeed
    }

    private var opacity: Double {
        animationPhase == 0 ? 0 : 1
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Confetti Modifier

struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool
    let colors: [Color]
    let particleCount: Int

    func body(content: Content) -> some View {
        content.overlay {
            ConfettiView(
                isActive: $isActive,
                colors: colors,
                particleCount: particleCount
            )
        }
    }
}

extension View {
    /// Adds confetti overlay triggered by binding
    func confetti(
        isActive: Binding<Bool>,
        colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink],
        particleCount: Int = 50
    ) -> some View {
        modifier(ConfettiModifier(
            isActive: isActive,
            colors: colors,
            particleCount: particleCount
        ))
    }
}

// MARK: - Preset Confetti Configurations

extension ConfettiView {
    /// Gold confetti for achievements
    static func gold(isActive: Binding<Bool>) -> ConfettiView {
        ConfettiView(
            isActive: isActive,
            colors: [.yellow, .orange, Color(red: 1, green: 0.84, blue: 0)],
            particleCount: 40
        )
    }

    /// Goal achieved confetti
    static func goalAchieved(isActive: Binding<Bool>) -> ConfettiView {
        ConfettiView(
            isActive: isActive,
            colors: [JW.Color.success, JW.Color.accent, JW.Color.success],
            particleCount: 45
        )
    }

    /// Streak milestone confetti
    static func streakMilestone(isActive: Binding<Bool>) -> ConfettiView {
        ConfettiView(
            isActive: isActive,
            colors: [JW.Color.streak, JW.Color.danger, JW.Color.accent],
            particleCount: 55
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showConfetti = false

        var body: some View {
            VStack {
                Button("Celebrate!") {
                    showConfetti = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .confetti(isActive: $showConfetti)
        }
    }

    return PreviewWrapper()
}
