//
//  GearInsightCard.swift
//  Just Walk
//
//  Letterboxd-style insight card for gear recommendations.
//

import SwiftUI

struct GearInsightCard: View {
    let insight: GearInsight
    let onCheckPrice: () -> Void
    let onDismiss: () -> Void
    let onStopSeeingThese: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground)
    }
    
    private var headerColor: Color {
        insight.type == .shoeWall ? .blue : .teal
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with gradient accent
            HStack {
                Circle()
                    .fill(headerColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: headerIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(headerColor)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.headline)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text(insight.type == .shoeWall ? "Shoe Maintenance" : "Activity Alert")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Body
            VStack(alignment: .leading, spacing: 14) {
                Text(insight.explanation)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Product Preview (if available)
                if let product = insight.product {
                    HStack(spacing: 12) {
                        // Product image placeholder
                        RoundedRectangle(cornerRadius: 10)
                            .fill(headerColor.opacity(0.1))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: productIcon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(headerColor)
                            }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.brand.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                            
                            Text(product.model)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            
                            Text(product.description)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
            
            // Footer
            VStack(spacing: 12) {
                // CTA Button
                Button {
                    onCheckPrice()
                } label: {
                    HStack {
                        Text("Check Price & Availability")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(headerColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Stop seeing these link
                Button {
                    onStopSeeingThese()
                } label: {
                    Text("Stop seeing these")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                // Affiliate Disclaimer - integrated nicely
                Text("As an affiliate partner, we may earn a commission.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .padding(.top, 0)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 16, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        }
    }
    
    private var headerIcon: String {
        switch insight.type {
        case .shoeWall:
            return "shoe.fill"
        case .deskTrap:
            return "desktopcomputer"
        }
    }
    
    private var productIcon: String {
        switch insight.type {
        case .shoeWall:
            return "shoe.fill"
        case .deskTrap:
            return "figure.walk.treadmill"
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        GearInsightCard(
            insight: GearInsight(
                type: .shoeWall,
                headline: "Equipment Health Alert",
                explanation: "Your shoes have covered 425 miles. Running shoes typically need replacement at 300-500 miles to maintain proper support.",
                product: RecommendedProduct(
                    id: "hoka-bondi-8",
                    category: "running_shoes",
                    brand: "Hoka",
                    model: "Bondi 8",
                    asin: "B0BXYZ123",
                    impactId: nil,
                    description: "Max-cushion daily trainer",
                    imageURL: nil
                )
            ),
            onCheckPrice: {},
            onDismiss: {},
            onStopSeeingThese: {}
        )
        .padding()
    }
}
