//
//  BackgroundSelector.swift
//  Just Walk
//
//  Horizontal scrolling picker for card background selection.
//  Shows free options and Pro-gated options with lock overlay.
//

import SwiftUI

struct BackgroundSelector: View {
    @Binding var selectedBackground: CardBackground
    @Binding var customColor: Color
    let rankColor: Color
    let isPro: Bool
    var onProBackgroundTapped: () -> Void = {}

    private let circleSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            Text("Background")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: JWDesign.Spacing.sm) {
                    // Free backgrounds
                    ForEach(CardBackground.freeBackgrounds) { background in
                        BackgroundOption(
                            background: background,
                            rankColor: rankColor,
                            customColor: customColor,
                            isSelected: selectedBackground == background,
                            isLocked: false
                        ) {
                            selectedBackground = background
                            HapticService.shared.playSelection()
                        }
                    }

                    // Separator
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 1, height: circleSize)

                    // Pro backgrounds
                    ForEach(CardBackground.proBackgrounds) { background in
                        BackgroundOption(
                            background: background,
                            rankColor: rankColor,
                            customColor: customColor,
                            isSelected: selectedBackground == background,
                            isLocked: !isPro
                        ) {
                            if isPro {
                                selectedBackground = background
                                HapticService.shared.playSelection()
                            } else {
                                onProBackgroundTapped()
                            }
                        }
                    }
                }
                .padding(.horizontal, JWDesign.Spacing.xs)
            }
        }
    }
}

// MARK: - Background Option Circle

private struct BackgroundOption: View {
    let background: CardBackground
    let rankColor: Color
    let customColor: Color
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void

    private let circleSize: CGFloat = 44

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle
                backgroundCircle

                // Lock overlay for Pro items
                if isLocked {
                    lockOverlay
                }

                // Selection ring
                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: circleSize + 4, height: circleSize + 4)
                }
            }
            .frame(width: circleSize + 8, height: circleSize + 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundCircle: some View {
        switch background {
        case .solidDark:
            Circle()
                .fill(rankColor.opacity(0.2))
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: circleSize - 4, height: circleSize - 4)
                )

        case .solidBlack:
            Circle()
                .fill(Color.black)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

        case .solidNavy:
            Circle()
                .fill(Color(hex: "1C2541"))
                .frame(width: circleSize, height: circleSize)

        case .gradientRank:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [rankColor, rankColor.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: circleSize, height: circleSize)

        case .natureForest:
            Circle()
                .fill(Color.green.opacity(0.7))
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                )

        case .natureBeach:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.8))
                )

        case .natureMountain:
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.8), .cyan.opacity(0.6)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                )

        case .customColor:
            // Rainbow gradient to indicate color picker
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    )
                )
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle()
                        .fill(customColor)
                        .frame(width: circleSize - 8, height: circleSize - 8)
                )
        }
    }

    private var lockOverlay: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: circleSize, height: circleSize)

            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Preview

#Preview("Background Selector - Free User") {
    VStack {
        BackgroundSelector(
            selectedBackground: .constant(.solidDark),
            customColor: .constant(.blue),
            rankColor: .orange,
            isPro: false
        ) {
            print("Pro tapped")
        }
    }
    .padding()
    .background(JWDesign.Colors.background)
}

#Preview("Background Selector - Pro User") {
    VStack {
        BackgroundSelector(
            selectedBackground: .constant(.gradientRank),
            customColor: .constant(.purple),
            rankColor: .purple,
            isPro: true
        )
    }
    .padding()
    .background(JWDesign.Colors.background)
}
