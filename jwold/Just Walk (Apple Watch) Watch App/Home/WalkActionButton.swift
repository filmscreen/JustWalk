//
//  WalkActionButton.swift
//  Just Walk Watch App
//
//  Reusable button component with primary/secondary styles.
//  Primary: 60pt height, teal background
//  Secondary: 55pt height, gray background
//

import SwiftUI

struct WalkActionButton: View {
    let icon: String
    let title: String
    let style: WalkActionButtonStyle
    var isPro: Bool = false
    let action: () -> Void

    enum WalkActionButtonStyle {
        case primary    // 60pt, teal bg
        case secondary  // 55pt, gray bg
    }

    private var height: CGFloat {
        style == .primary ? 60 : 55
    }

    private var backgroundColor: Color {
        style == .primary ? Color.teal : Color.gray.opacity(0.2)
    }

    private var foregroundColor: Color {
        style == .primary ? .white : .primary
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                    if isPro {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Primary") {
    VStack(spacing: 12) {
        WalkActionButton(
            icon: "figure.walk",
            title: "Just Walk",
            style: .primary,
            action: {}
        )
        WalkActionButton(
            icon: "timer",
            title: "With Goal",
            style: .secondary,
            action: {}
        )
        WalkActionButton(
            icon: "bolt.fill",
            title: "Interval",
            style: .secondary,
            isPro: true,
            action: {}
        )
    }
    .padding()
}
