//
//  AnimationModifiers.swift
//  JustWalk
//
//  Custom view modifiers for animations
//

import SwiftUI

// MARK: - Button Press Effect

struct ButtonPressEffect: ViewModifier {
    @State private var isPressed = false

    let scale: CGFloat
    let animation: Animation

    init(scale: CGFloat = 0.95, animation: Animation = JustWalkAnimation.micro) {
        self.scale = scale
        self.animation = animation
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(animation, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            JustWalkHaptics.buttonTap()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - Staggered Appearance

struct StaggeredAppearance: ViewModifier {
    let index: Int
    let baseDelay: Double

    @State private var isVisible = false

    init(index: Int, baseDelay: Double = 0.05) {
        self.index = index
        self.baseDelay = baseDelay
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(JustWalkAnimation.stagger(for: index, baseDelay: baseDelay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Pulse Effect

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    let minScale: CGFloat
    let maxScale: CGFloat

    init(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05) {
        self.minScale = minScale
        self.maxScale = maxScale
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .animation(JustWalkAnimation.pulse, value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Shake Effect

struct ShakeEffect: ViewModifier {
    @Binding var trigger: Bool

    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(JustWalkAnimation.shake) {
                        shakeOffset = -10
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(JustWalkAnimation.shake) {
                            shakeOffset = 10
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(JustWalkAnimation.shake) {
                            shakeOffset = -5
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(JustWalkAnimation.shake) {
                            shakeOffset = 0
                        }
                        trigger = false
                    }
                }
            }
    }
}

// MARK: - Bounce In Effect

struct BounceInEffect: ViewModifier {
    @State private var isVisible = false

    let delay: Double

    init(delay: Double = 0) {
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(JustWalkAnimation.emphasis.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Slide In Effect

struct SlideInEffect: ViewModifier {
    let edge: Edge
    let delay: Double

    @State private var isVisible = false

    init(from edge: Edge = .bottom, delay: Double = 0) {
        self.edge = edge
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(slideOffset)
            .onAppear {
                withAnimation(JustWalkAnimation.presentation.delay(delay)) {
                    isVisible = true
                }
            }
    }

    private var slideOffset: CGSize {
        guard !isVisible else { return .zero }

        switch edge {
        case .top:
            return CGSize(width: 0, height: -50)
        case .bottom:
            return CGSize(width: 0, height: 50)
        case .leading:
            return CGSize(width: -50, height: 0)
        case .trailing:
            return CGSize(width: 50, height: 0)
        }
    }
}

// MARK: - Glow Effect

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.6) : .clear, radius: radius)
            .animation(JustWalkAnimation.standard, value: isActive)
    }
}

// MARK: - View Extensions

extension View {
    /// Adds press-down scale effect to buttons
    func pressEffect(scale: CGFloat = 0.95) -> some View {
        modifier(ButtonPressEffect(scale: scale))
    }

    /// Staggered appearance animation for list items
    func staggeredAppearance(index: Int, delay: Double = 0.05) -> some View {
        modifier(StaggeredAppearance(index: index, baseDelay: delay))
    }

    /// Continuous pulse animation
    func pulseEffect(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05) -> some View {
        modifier(PulseEffect(minScale: minScale, maxScale: maxScale))
    }

    /// Shake animation triggered by binding
    func shakeEffect(trigger: Binding<Bool>) -> some View {
        modifier(ShakeEffect(trigger: trigger))
    }

    /// Bounce in animation on appear
    func bounceIn(delay: Double = 0) -> some View {
        modifier(BounceInEffect(delay: delay))
    }

    /// Slide in from edge on appear
    func slideIn(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        modifier(SlideInEffect(from: edge, delay: delay))
    }

    /// Glow effect when active
    func glowEffect(color: Color = .blue, radius: CGFloat = 10, isActive: Bool) -> some View {
        modifier(GlowEffect(color: color, radius: radius, isActive: isActive))
    }

    /// Button press effect with default scale
    func buttonPressEffect() -> some View {
        modifier(ButtonPressEffect())
    }
}
