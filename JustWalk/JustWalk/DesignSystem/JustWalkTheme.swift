//
//  JustWalkTheme.swift
//  JustWalk
//
//  Design system tokens: colors, fonts, spacing, radii, and reusable modifiers
//

import SwiftUI

// MARK: - JW Namespace

enum JW {

    // MARK: - Colors

    enum Color {
        static let backgroundPrimary = SwiftUI.Color(red: 0x12/255, green: 0x12/255, blue: 0x20/255)
        static let backgroundCard = SwiftUI.Color(red: 0x1C/255, green: 0x1C/255, blue: 0x2E/255)
        static let backgroundTertiary = SwiftUI.Color(red: 0x26/255, green: 0x26/255, blue: 0x3B/255)

        static let accent = SwiftUI.Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)        // Active Green
        static let accentBlue = SwiftUI.Color(red: 0x40/255, green: 0x85/255, blue: 0xFF/255)
        static let accentPurple = SwiftUI.Color(red: 0x8C/255, green: 0x45/255, blue: 0xFF/255)
        static let success = SwiftUI.Color(red: 0x4D/255, green: 0xD9/255, blue: 0x66/255)
        static let streak = SwiftUI.Color(red: 0xFF/255, green: 0x73/255, blue: 0x1A/255)
        static let danger = SwiftUI.Color(red: 0xFF/255, green: 0x59/255, blue: 0x59/255)

        // Phase colors for interval training
        static let phaseWarmup  = SwiftUI.Color(red: 0xFF/255, green: 0x8C/255, blue: 0x00/255)  // Amber/Orange
        static let phaseFast    = SwiftUI.Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)  // Green
        static let phaseSlow    = SwiftUI.Color(red: 0x40/255, green: 0x85/255, blue: 0xFF/255)  // Blue
        static let phaseCooldown = SwiftUI.Color(red: 0x8C/255, green: 0x45/255, blue: 0xFF/255) // Purple

        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.6)
        static let textTertiary = SwiftUI.Color.white.opacity(0.45)

        // Ring gradient palette (emerald → brand green → bright mint)
        static let ringStart = SwiftUI.Color(red: 0x20/255, green: 0xA0/255, blue: 0x80/255)
        static let ringEnd   = SwiftUI.Color(red: 0x86/255, green: 0xEF/255, blue: 0xAC/255)

        /// Step ring gradient: seamless loop so the round cap at 0°/360° has no seam
        static let ringGradient = AngularGradient(
            stops: [
                .init(color: ringStart, location: 0.0),
                .init(color: accent,    location: 0.35),
                .init(color: ringEnd,   location: 0.7),
                .init(color: ringStart, location: 1.0)
            ],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )

        /// Background gradient for launch / hero sections
        static let heroGradient = LinearGradient(
            colors: [
                SwiftUI.Color(red: 0x0D/255, green: 0x0D/255, blue: 0x1A/255),
                backgroundPrimary,
                SwiftUI.Color(red: 0x16/255, green: 0x14/255, blue: 0x28/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Fonts (Rounded)

    enum Font {
        static let heroNumber = SwiftUI.Font.system(size: 56, weight: .bold, design: .rounded)
        static let largeTitle = SwiftUI.Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title1 = SwiftUI.Font.system(.title, design: .rounded, weight: .bold)
        static let title2 = SwiftUI.Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = SwiftUI.Font.system(.title3, design: .rounded, weight: .semibold)
        static let headline = SwiftUI.Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = SwiftUI.Font.system(.body, design: .rounded)
        static let callout = SwiftUI.Font.system(.callout, design: .rounded)
        static let subheadline = SwiftUI.Font.system(.subheadline, design: .rounded)
        static let footnote = SwiftUI.Font.system(.footnote, design: .rounded)
        static let caption = SwiftUI.Font.system(.caption, design: .rounded)
        static let caption2 = SwiftUI.Font.system(.caption2, design: .rounded)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 100
    }

}

// MARK: - Card View Modifier

struct JWCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func jwCard() -> some View {
        modifier(JWCardModifier())
    }
}

// MARK: - Section Header

struct JWSectionHeader: View {
    let title: String
    let action: String?
    let onAction: (() -> Void)?

    init(_ title: String, action: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title
        self.action = action
        self.onAction = onAction
    }

    var body: some View {
        HStack {
            Text(title)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            if let action = action, let onAction = onAction {
                Button(action: onAction) {
                    Text(action)
                        .font(JW.Font.subheadline.weight(.bold))
                        .foregroundStyle(JW.Color.accentBlue)
                }
            }
        }
    }
}
