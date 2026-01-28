//
//  KitProductCard.swift
//  Just Walk
//
//  Product card for the Kit tab with categorical badging system.
//

import SwiftUI

struct KitProductCard: View {
    let product: KitProduct
    let onDirectLink: () -> Void
    let onAmazonLink: () -> Void
    var onMensLink: (() -> Void)? = nil
    var onWomensLink: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        switch product.category {
        case .footwear: return .blue
        case .walkingPads: return .teal
        case .recovery: return .purple
        case .supplements: return .green
        case .intensity: return .orange
        }
    }

    /// Badge color based on badge type
    private var badgeColor: Color {
        switch product.effectiveBadge {
        case .bestValue:
            return Color(red: 0.85, green: 0.65, blue: 0.13) // Deep gold
        case .mostPopular:
            return Color(red: 1.0, green: 0.42, blue: 0.42) // Vibrant coral
        case .editorsPick:
            return JWDesign.Colors.brandSecondary // Teal
        }
    }

    /// Badge gradient for premium feel
    private var badgeGradient: LinearGradient {
        switch product.effectiveBadge {
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

    /// Badge icon based on type
    private var badgeIcon: String {
        switch product.effectiveBadge {
        case .bestValue: return "star.fill"
        case .mostPopular: return "flame.fill"
        case .editorsPick: return "checkmark.seal.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product Header with Image
            productImageSection

            // Product Info
            VStack(alignment: .leading, spacing: 8) {
                // Brand
                Text(product.brand.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)

                // Model + Badge Row
                HStack(alignment: .center, spacing: JWDesign.Spacing.sm) {
                    Text(product.model)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    Spacer(minLength: JWDesign.Spacing.sm)

                    // Categorical Badge (always shown)
                    categoryBadge
                }
                
                Text(product.description)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                
                // Strategic Benefit
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)
                    
                    Text(product.strategicBenefit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                        .italic()
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // CTA Buttons
                HStack(spacing: 12) {
                    if product.hasGenderLinks {
                        // Men's Link Button
                        Button {
                            onMensLink?()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Men")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accentColor)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        // Women's Link Button
                        Button {
                            onWomensLink?()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Women")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accentColor)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else if product.amazonURL != nil {
                        // Single Amazon Link Button (full width)
                        Button {
                            onAmazonLink()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Amazon")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accentColor)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                
                // Affiliate disclaimer
                Text("As an affiliate partner, we may earn a commission.")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
    }

    // MARK: - Product Image Section

    private var productImageSection: some View {
        Group {
            // Product image area - prefer local image, then remote, then fallback
            if let imageName = product.imageName, UIImage(named: imageName) != nil {
                // Local asset image
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
                    .allowsHitTesting(false)
            } else if let imageURL = product.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 120)
                            .overlay {
                                ProgressView()
                                    .tint(accentColor)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .clipped()
                            .allowsHitTesting(false)
                    case .failure:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 120)
                            .overlay {
                                Image(systemName: categoryIcon)
                                    .font(.system(size: 40))
                                    .foregroundStyle(accentColor.opacity(0.4))
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Fallback: gradient with category icon
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: categoryIcon)
                            .font(.system(size: 40))
                            .foregroundStyle(accentColor.opacity(0.4))
                    }
            }
        }
    }

    // MARK: - Category Badge

    /// Pill-shaped badge with unique color-coding based on badge type
    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: badgeIcon)
                .font(.system(size: 9, weight: .bold))

            Text(product.effectiveBadge.rawValue)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(badgeGradient)
        .clipShape(Capsule())
        .shadow(color: badgeColor.opacity(0.4), radius: 4, y: 2)
    }

    // MARK: - Helpers

    private var categoryIcon: String {
        switch product.category {
        case .footwear: return "shoe.fill"
        case .walkingPads: return "figure.walk.treadmill"
        case .recovery: return "heart.circle.fill"
        case .supplements: return "pills.fill"
        case .intensity: return "dumbbell.fill"
        }
    }
}

#Preview("Best Value Badge") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()

        KitProductCard(
            product: KitProduct(
                id: "hoka-bondi-8",
                category: .footwear,
                brand: "Hoka",
                model: "Bondi 8",
                description: "Max-cushion daily trainer",
                strategicBenefit: "Protect your joints to ensure zero-day gaps in your journey.",
                imageURL: URL(string: "https://www.hoka.com/dw/image/v2/BDJD_PRD/on/demandware.static/-/Sites-hoka-master/default/dw7fefb7e3/images/grey/1123202-BBLC_1.jpg"),
                directURL: URL(string: "https://www.hoka.com/en/us/mens-everyday/bondi-8/1123202.html"),
                amazonURL: URL(string: "https://www.amazon.com/dp/B0B3MTRL1V"),
                productBadge: .bestValue,
                isPinned: true
            ),
            onDirectLink: {},
            onAmazonLink: {}
        )
        .padding()
    }
}

#Preview("Most Popular Badge") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()

        KitProductCard(
            product: KitProduct(
                id: "walkingpad-c2",
                category: .walkingPads,
                brand: "WalkingPad",
                model: "C2 Folding Treadmill",
                description: "Compact under-desk walking pad",
                strategicBenefit: "Turn screen time into step time without leaving home.",
                directURL: URL(string: "https://www.walkingpad.com"),
                amazonURL: URL(string: "https://www.amazon.com/dp/B08XYZ"),
                productBadge: .mostPopular,
                isPinned: false
            ),
            onDirectLink: {},
            onAmazonLink: {}
        )
        .padding()
    }
}

#Preview("Editor's Pick (Default)") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()

        KitProductCard(
            product: KitProduct(
                id: "theragun-prime",
                category: .recovery,
                brand: "Therabody",
                model: "Theragun Prime",
                description: "Percussion massage device",
                strategicBenefit: "Accelerate recovery to walk stronger tomorrow.",
                directURL: URL(string: "https://www.therabody.com"),
                amazonURL: URL(string: "https://www.amazon.com/dp/B08ABC"),
                isPinned: false
            ),
            onDirectLink: {},
            onAmazonLink: {}
        )
        .padding()
    }
}

// MARK: - Compact Product Card (for Horizontal Carousels)

struct CompactProductCard: View {
    let product: KitProduct
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        switch product.category {
        case .footwear: return .blue
        case .walkingPads: return .teal
        case .recovery: return .purple
        case .supplements: return .green
        case .intensity: return .orange
        }
    }

    /// Badge gradient for premium feel (matching full card)
    private var badgeGradient: LinearGradient {
        switch product.effectiveBadge {
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

    private var badgeIcon: String {
        switch product.effectiveBadge {
        case .bestValue: return "star.fill"
        case .mostPopular: return "flame.fill"
        case .editorsPick: return "checkmark.seal.fill"
        }
    }

    private var categoryIcon: String {
        switch product.category {
        case .footwear: return "shoe.fill"
        case .walkingPads: return "figure.walk.treadmill"
        case .recovery: return "heart.circle.fill"
        case .supplements: return "pills.fill"
        case .intensity: return "dumbbell.fill"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: JWDesign.Spacing.xs) {
                // Product image with badge overlay
                ZStack(alignment: .topTrailing) {
                    productImage
                        .frame(width: 160, height: 100)
                        .background(JWDesign.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))

                    // Badge overlay
                    compactBadge
                        .offset(x: -6, y: 6)
                }

                // Brand (simplified - no uppercase)
                Text(product.brand)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.tertiary)

                // Model name (lighter weight)
                Text(product.model)
                    .font(JWDesign.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 160)
        }
        .buttonStyle(CompactCardButtonStyle())
    }

    // MARK: - Product Image

    @ViewBuilder
    private var productImage: some View {
        if let imageName = product.imageName, UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let imageURL = product.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            ProgressView()
                                .tint(accentColor)
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    fallbackImage
                @unknown default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [accentColor.opacity(0.15), accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: categoryIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(accentColor.opacity(0.4))
            }
    }

    // MARK: - Compact Badge

    private var compactBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: badgeIcon)
                .font(.system(size: 8, weight: .bold))
            Text(product.effectiveBadge.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(badgeGradient)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}

// MARK: - Compact Card Button Style

private struct CompactCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(JWDesign.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Product Detail Sheet

struct ProductDetailSheet: View {
    let product: KitProduct
    let onDirectLink: () -> Void
    let onAmazonLink: () -> Void
    var onMensLink: (() -> Void)? = nil
    var onWomensLink: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    KitProductCard(
                        product: product,
                        onDirectLink: onDirectLink,
                        onAmazonLink: onAmazonLink,
                        onMensLink: onMensLink,
                        onWomensLink: onWomensLink
                    )
                    .padding(JWDesign.Spacing.horizontalInset)
                    .padding(.top, JWDesign.Spacing.md)
                }
            }
            .background(JWDesign.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview("Compact Card") {
    ZStack {
        JWDesign.Colors.background.ignoresSafeArea()

        HStack(spacing: JWDesign.Spacing.md) {
            CompactProductCard(
                product: KitProduct(
                    id: "hoka-bondi-8",
                    category: .footwear,
                    brand: "Hoka",
                    model: "Bondi 8",
                    description: "Max-cushion daily trainer",
                    strategicBenefit: "Protect your joints.",
                    directURL: URL(string: "https://www.hoka.com"),
                    amazonURL: URL(string: "https://www.amazon.com/dp/B0B3MTRL1V"),
                    productBadge: .bestValue,
                    isPinned: true
                ),
                onTap: {}
            )

            CompactProductCard(
                product: KitProduct(
                    id: "walkingpad-c2",
                    category: .walkingPads,
                    brand: "WalkingPad",
                    model: "C2 Folding",
                    description: "Compact treadmill",
                    strategicBenefit: "Walk from home.",
                    amazonURL: URL(string: "https://www.amazon.com/dp/B08XYZ"),
                    productBadge: .mostPopular,
                    isPinned: false
                ),
                onTap: {}
            )
        }
        .padding()
    }
}
