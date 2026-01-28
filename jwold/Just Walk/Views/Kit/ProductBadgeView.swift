//
//  ProductBadgeView.swift
//  Just Walk
//
//  Reusable categorical badge component for Level Up product tiles.
//  Supports Best Value, Most Popular, and Editor's Pick badges.
//

import SwiftUI

// MARK: - Badge Type

/// Badge type for product categorization
enum ProductBadgeType: String, Codable, CaseIterable {
    case bestValue = "Best Value"
    case mostPopular = "Most Popular"
    case editorsPick = "Editor's Pick"

    /// Display text for the badge
    var displayText: String {
        rawValue
    }

    /// Icon for the badge
    var icon: String {
        switch self {
        case .bestValue: return "star.fill"
        case .mostPopular: return "flame.fill"
        case .editorsPick: return "checkmark.seal.fill"
        }
    }

    /// Primary badge color
    var color: Color {
        switch self {
        case .bestValue:
            // Deep gold with premium feel
            return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .mostPopular:
            // Vibrant coral/orange
            return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .editorsPick:
            // Brand teal
            return JWDesign.Colors.brandSecondary
        }
    }

    /// Gradient for premium badge backgrounds
    var gradient: LinearGradient {
        switch self {
        case .bestValue:
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.75, blue: 0.20),
                    Color(red: 0.80, green: 0.55, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mostPopular:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.50, blue: 0.45),
                    Color(red: 0.95, green: 0.35, blue: 0.40)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .editorsPick:
            return LinearGradient(
                colors: [
                    JWDesign.Colors.brandSecondary,
                    JWDesign.Colors.brandPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Product Badge View

/// Reusable pill-shaped badge for product tiles
struct ProductBadgeView: View {
    let badgeType: ProductBadgeType

    /// Compact mode for tighter spaces
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: isCompact ? 3 : 4) {
            Image(systemName: badgeType.icon)
                .font(.system(size: isCompact ? 8 : 9, weight: .bold))

            Text(badgeType.displayText)
                .font(.system(size: isCompact ? 9 : 10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 3 : 4)
        .background(badgeType.gradient)
        .clipShape(Capsule())
        .shadow(color: badgeType.color.opacity(0.4), radius: 4, y: 2)
    }
}

// MARK: - Badge Determination Logic

extension ProductBadgeType {
    /// Determines the appropriate badge type based on product metadata
    /// Falls back to Editor's Pick if no specific badge is assigned
    static func determine(from badgeText: String?) -> ProductBadgeType {
        guard let text = badgeText?.lowercased() else {
            return .editorsPick
        }

        if text.contains("best value") || text.contains("value") {
            return .bestValue
        } else if text.contains("most popular") || text.contains("popular") || text.contains("top seller") {
            return .mostPopular
        } else {
            // Default fallback for any other badge text
            return .editorsPick
        }
    }
}

// MARK: - Product Title Row with Badge

/// A row component that displays product title with trailing badge
/// Ensures badge doesn't overlap with long product names
struct ProductTitleWithBadge: View {
    let title: String
    let badgeType: ProductBadgeType

    var body: some View {
        HStack(alignment: .center, spacing: JWDesign.Spacing.sm) {
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Spacer(minLength: JWDesign.Spacing.sm)

            ProductBadgeView(badgeType: badgeType, isCompact: false)
        }
    }
}

// MARK: - Preview

#Preview("Badge Types") {
    VStack(spacing: 24) {
        // Individual badges
        VStack(alignment: .leading, spacing: 12) {
            Text("Badge Variants")
                .font(.headline)

            HStack(spacing: 12) {
                ProductBadgeView(badgeType: .bestValue)
                ProductBadgeView(badgeType: .mostPopular)
                ProductBadgeView(badgeType: .editorsPick)
            }

            Text("Compact Badges")
                .font(.headline)
                .padding(.top)

            HStack(spacing: 8) {
                ProductBadgeView(badgeType: .bestValue, isCompact: true)
                ProductBadgeView(badgeType: .mostPopular, isCompact: true)
                ProductBadgeView(badgeType: .editorsPick, isCompact: true)
            }
        }

        Divider()

        // Title with badge examples
        VStack(alignment: .leading, spacing: 16) {
            Text("Title + Badge Layout")
                .font(.headline)

            ProductTitleWithBadge(
                title: "Bondi 8",
                badgeType: .bestValue
            )

            ProductTitleWithBadge(
                title: "WalkingPad C2 Folding Treadmill",
                badgeType: .mostPopular
            )

            ProductTitleWithBadge(
                title: "Theragun Prime",
                badgeType: .editorsPick
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
