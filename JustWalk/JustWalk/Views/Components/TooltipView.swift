//
//  TooltipView.swift
//  JustWalk
//
//  Reusable tooltip component for first-time feature discovery
//

import SwiftUI

// MARK: - Tooltip Arrow Direction

enum TooltipArrowDirection {
    case up
    case down
    case left
    case right
}

// MARK: - Tooltip View

struct TooltipView: View {
    let content: String
    let arrowDirection: TooltipArrowDirection
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            if arrowDirection == .down {
                arrowShape
                    .rotationEffect(.degrees(180))
            }

            HStack(spacing: 0) {
                if arrowDirection == .right {
                    arrowShape
                        .rotationEffect(.degrees(-90))
                }

                tooltipContent

                if arrowDirection == .left {
                    arrowShape
                        .rotationEffect(.degrees(90))
                }
            }

            if arrowDirection == .up {
                arrowShape
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    private var tooltipContent: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            Text(content)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                JustWalkHaptics.buttonTap()
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDismiss()
                }
            } label: {
                Text("Got it")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
        }
        .padding(JW.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private var arrowShape: some View {
        TooltipArrow()
            .fill(JW.Color.backgroundCard)
            .frame(width: 16, height: 8)
    }
}

// MARK: - Tooltip Arrow Shape

private struct TooltipArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Tooltip Overlay Modifier

struct TooltipOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    let content: String
    let arrowDirection: TooltipArrowDirection
    let offset: CGSize
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment(for: arrowDirection)) {
                if isPresented {
                    TooltipView(
                        content: self.content,
                        arrowDirection: arrowDirection,
                        onDismiss: {
                            isPresented = false
                            onDismiss()
                        }
                    )
                    .offset(offset)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
    }

    private func alignment(for direction: TooltipArrowDirection) -> Alignment {
        switch direction {
        case .up: return .bottom
        case .down: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

extension View {
    func tooltip(
        isPresented: Binding<Bool>,
        content: String,
        arrowDirection: TooltipArrowDirection = .up,
        offset: CGSize = .zero,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        modifier(TooltipOverlayModifier(
            isPresented: isPresented,
            content: content,
            arrowDirection: arrowDirection,
            offset: offset,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Tooltip Keys (UserDefaults)

enum TooltipKey: String {
    case shields = "hasSeenShieldsTooltip"
    case calories = "hasSeenCaloriesTooltip"
    case walks = "hasSeenWalksTooltip"

    var hasBeenSeen: Bool {
        get { UserDefaults.standard.bool(forKey: rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: rawValue) }
    }

    static func markAsSeen(_ key: TooltipKey) {
        UserDefaults.standard.set(true, forKey: key.rawValue)
    }

    static func shouldShow(_ key: TooltipKey) -> Bool {
        !UserDefaults.standard.bool(forKey: key.rawValue)
    }
}

// MARK: - Previews

#Preview("Tooltip Up") {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()

        VStack {
            Spacer()

            Circle()
                .fill(JW.Color.backgroundCard)
                .frame(width: 60, height: 60)
                .tooltip(
                    isPresented: .constant(true),
                    content: "Shields protect your streak when life happens. Use one if you miss a day.",
                    arrowDirection: .up,
                    offset: CGSize(width: 0, height: 8)
                )

            Spacer()
        }
    }
}

#Preview("Tooltip Down") {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()

        VStack {
            Spacer()

            Circle()
                .fill(JW.Color.backgroundCard)
                .frame(width: 60, height: 60)
                .tooltip(
                    isPresented: .constant(true),
                    content: "Your calories today. Tap to see details in Fuel.",
                    arrowDirection: .down,
                    offset: CGSize(width: 0, height: -8)
                )

            Spacer()
        }
    }
}
