//
//  JustWalkDesignSystem.swift
//  Just Walk
//
//  Unified design system for iOS 26 consistency.
//  All views should reference these tokens for a cohesive experience.
//

import SwiftUI

// MARK: - Design Tokens

struct JWDesign {

    // MARK: - Color Palette

    struct Colors {
        // Primary Brand Colors (Blue/Teal theme from app icon)
        static let brandPrimary = Color.blue
        static let brandSecondary = Color.teal
        static let brandAccent = Color.cyan

        // Semantic Colors
        static let success = Color.mint
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        // Step Progress Colors (threshold-based)
        static func stepProgress(_ percentage: Double) -> Color {
            switch percentage {
            case ..<0.25: return .blue.opacity(0.8)
            case 0.25..<0.50: return .blue
            case 0.50..<0.75: return .cyan
            case 0.75..<1.0: return .teal
            default: return .mint
            }
        }

        // Category Colors (for Kit tab)
        static let footwear = Color.blue
        static let walkingPads = Color.teal
        static let recovery = Color.purple
        static let supplements = Color.green
        static let intensity = Color.orange

        // Rank Colors
        static let gold = Color.yellow
        static let silver = Color(.systemGray5)
        static let bronze = Color.orange

        // Adaptive Backgrounds
        static var background: Color { Color(.systemGroupedBackground) }
        static var secondaryBackground: Color { Color(.secondarySystemGroupedBackground) }
        static var tertiaryBackground: Color { Color(.tertiarySystemGroupedBackground) }
    }

    // MARK: - Gradients

    struct Gradients {
        // Primary brand gradient (used in buttons, progress rings)
        static let brand = LinearGradient(
            colors: [.teal, .cyan, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Progress ring gradient
        static let progressRing = AngularGradient(
            colors: [.teal, .cyan, .blue, .teal],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )

        // Completed/Victory gradient (deep teal to blue)
        static let victory = LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.35, blue: 0.45),
                Color(red: 0.05, green: 0.25, blue: 0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Warmup phase
        static let warmup = LinearGradient(
            colors: [Color.orange.opacity(0.8), Color.yellow.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Brisk phase
        static let brisk = LinearGradient(
            colors: [Color.red.opacity(0.8), Color.orange.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Recovery phase
        static let recovery = LinearGradient(
            colors: [Color.green.opacity(0.8), Color.teal.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Cooldown phase
        static let cooldown = LinearGradient(
            colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Classic walk
        static let classic = LinearGradient(
            colors: [Color.cyan.opacity(0.8), Color.green.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography
    // All fonts use semantic text styles for Dynamic Type accessibility

    struct Typography {
        // Display (large titles, hero numbers) - use semantic fonts for scaling
        // Note: For very large displays like progress ring number, use @ScaledMetric in the view
        static let displayLarge = Font.largeTitle.weight(.bold)
        static let displayMedium = Font.title.weight(.bold)
        static let displaySmall = Font.title2.weight(.bold)

        // Headlines
        static let headline = Font.headline
        static let headlineBold = Font.headline.weight(.bold)

        // Subheadlines
        static let subheadline = Font.subheadline
        static let subheadlineBold = Font.subheadline.weight(.semibold)

        // Body
        static let body = Font.body
        static let bodyBold = Font.body.weight(.semibold)

        // Captions
        static let caption = Font.caption
        static let captionBold = Font.caption.weight(.bold)
        static let caption2 = Font.caption2

        // Monospaced (for numbers, codes) - kept fixed for alignment consistency
        static let monoLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
        static let monoMedium = Font.system(size: 16, weight: .semibold, design: .monospaced)
        static let monoSmall = Font.system(size: 13, weight: .medium, design: .monospaced)

        // Metadata (uppercase tracking)
        static let metadata = Font.caption2.weight(.bold)
    }

    // MARK: - Card Typography (standardized for TodayView cards)
    // Uses semantic fonts for Dynamic Type accessibility

    struct CardTypography {
        /// Card title - scales with Dynamic Type
        static let title = Font.subheadline.weight(.semibold)
        /// Card body - scales with Dynamic Type
        static let body = Font.footnote
        /// Card link - scales with Dynamic Type
        static let link = Font.footnote
    }

    // MARK: - Card Layout (standardized for TodayView cards)

    struct CardLayout {
        static let padding: CGFloat = 16
        static let iconSize: CGFloat = 32
        static let iconInnerSize: CGFloat = 16
        static let iconTextSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 20
    }

    // MARK: - Spacing

    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32

        // Specific use cases
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let listRowSpacing: CGFloat = 12
        static let horizontalInset: CGFloat = 16
        static let tabBarSafeArea: CGFloat = 80
    }

    // MARK: - Corner Radius

    struct Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let card: CGFloat = 20
        static let button: CGFloat = 12
        static let pill: CGFloat = 999
    }

    // MARK: - Shadows

    struct Shadows {
        static func card(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (
                color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08),
                radius: 12,
                y: 4
            )
        }

        static func elevated(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (
                color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                radius: 20,
                y: 10
            )
        }

        static func button(color: Color) -> (color: Color, radius: CGFloat, y: CGFloat) {
            (
                color: color.opacity(0.3),
                radius: 8,
                y: 4
            )
        }
    }

    // MARK: - Animation

    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
        static let bouncy = SwiftUI.Animation.bouncy(duration: 0.4, extraBounce: 0.15)
    }

    // MARK: - Icon Sizes

    struct IconSize {
        static let small: CGFloat = 14
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
}

// MARK: - Shared View Modifiers

struct JWCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shadow = JWDesign.Shadows.card(colorScheme: colorScheme)
        content
            .padding(JWDesign.CardLayout.padding)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.CardLayout.cornerRadius))
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

// MARK: - Card Icon Component

/// Standardized icon with circular background for TodayView cards
struct CardIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: JWDesign.CardLayout.iconSize, height: JWDesign.CardLayout.iconSize)
            Image(systemName: systemName)
                .font(.system(size: JWDesign.CardLayout.iconInnerSize, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

struct JWPrimaryButtonStyle: ButtonStyle {
    var color: Color = JWDesign.Colors.brandPrimary

    func makeBody(configuration: Configuration) -> some View {
        let shadow = JWDesign.Shadows.button(color: color)
        configuration.label
            .font(JWDesign.Typography.headlineBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(Capsule())
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(JWDesign.Animation.quick, value: configuration.isPressed)
    }
}

struct JWGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(JWDesign.Typography.headlineBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(JWDesign.Gradients.brand)
            .clipShape(Capsule())
            .shadow(color: .blue.opacity(0.25), radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(JWDesign.Animation.quick, value: configuration.isPressed)
    }
}

struct JWSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(JWDesign.Typography.subheadlineBold)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(JWDesign.Animation.quick, value: configuration.isPressed)
    }
}

struct JWTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(JWDesign.Typography.body)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(JWDesign.Colors.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: JWDesign.Radius.medium)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func jwCardStyle() -> some View {
        modifier(JWCardStyle())
    }

    func jwTextFieldStyle() -> some View {
        modifier(JWTextFieldStyle())
    }
}

// MARK: - Shared Components

/// Standardized stat card used across Dashboard, DataView, etc.
struct JWStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(JWDesign.Typography.headline)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                Text(title)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(JWDesign.Typography.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(JWDesign.Spacing.cardPadding)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }
}

/// Standardized section header
struct JWSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil

    var body: some View {
        HStack(spacing: JWDesign.Spacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: JWDesign.IconSize.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                Text(title)
                    .font(JWDesign.Typography.headline)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.top, JWDesign.Spacing.sm)
    }
}

/// Standardized row item for lists
struct JWListRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .blue
    var trailingText: String? = nil
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: JWDesign.Spacing.md) {
            if let icon = icon {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: JWDesign.IconSize.medium))
                        .foregroundStyle(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                Text(title)
                    .font(JWDesign.Typography.subheadlineBold)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let trailingText = trailingText {
                Text(trailingText)
                    .font(JWDesign.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(JWDesign.Spacing.cardPadding)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }
}

// MARK: - Preview

#Preview("Design System") {
    ScrollView {
        VStack(spacing: 24) {
            // Colors
            HStack(spacing: 12) {
                Circle().fill(JWDesign.Colors.brandPrimary).frame(width: 40, height: 40)
                Circle().fill(JWDesign.Colors.brandSecondary).frame(width: 40, height: 40)
                Circle().fill(JWDesign.Colors.brandAccent).frame(width: 40, height: 40)
                Circle().fill(JWDesign.Colors.success).frame(width: 40, height: 40)
            }

            // Buttons
            Button("Primary Button") {}
                .buttonStyle(JWPrimaryButtonStyle())

            Button("Gradient Button") {}
                .buttonStyle(JWGradientButtonStyle())

            Button("Secondary Button") {}
                .buttonStyle(JWSecondaryButtonStyle())

            // Cards
            JWStatCard(
                title: "Average",
                value: "8,432",
                icon: "chart.bar.fill",
                color: .blue,
                subtitle: "steps/day"
            )

            JWSectionHeader(
                title: "Recommendations",
                subtitle: "Curated for you",
                icon: "sparkles"
            )

            JWListRow(
                title: "Daily Goal",
                subtitle: "10,000 steps",
                icon: "target",
                iconColor: .blue,
                showChevron: true
            )
        }
        .padding()
    }
    .background(JWDesign.Colors.background)
}
