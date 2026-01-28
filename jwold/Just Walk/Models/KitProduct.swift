//
//  KitProduct.swift
//  Just Walk
//
//  Product model for the Kit tab with strategic benefits.
//

import Foundation

/// Product category for the Kit tab
enum KitCategory: String, Codable, CaseIterable {
    case footwear
    case walkingPads
    case recovery
    case supplements
    case intensity
}

/// Badge type for product categorization (stored in model)
enum KitProductBadge: String, Codable {
    case bestValue = "Best Value"
    case mostPopular = "Most Popular"
    case editorsPick = "Editor's Pick"
}

/// A product for the Kit tab with smart prioritization support
struct KitProduct: Identifiable, Codable {
    let id: String
    let category: KitCategory
    let brand: String
    let model: String
    let description: String
    let strategicBenefit: String
    let imageName: String?       // Local asset image name
    let imageURL: URL?           // Remote product image (fallback)
    let directURL: URL?          // Direct link to manufacturer website
    let amazonURL: URL?          // Amazon product page (for affiliate linking)
    let amazonMensURL: URL?      // Amazon Men's product link
    let amazonWomensURL: URL?    // Amazon Women's product link
    var badgeText: String?       // Legacy badge text (for backward compatibility)
    var productBadge: KitProductBadge?  // New typed badge
    var isPinned: Bool

    /// Whether this product has gender-specific links
    var hasGenderLinks: Bool {
        amazonMensURL != nil && amazonWomensURL != nil
    }

    // Custom initializer with defaults for optional parameters
    init(
        id: String,
        category: KitCategory,
        brand: String,
        model: String,
        description: String,
        strategicBenefit: String,
        asin: String? = nil,       // Legacy, ignored
        impactId: String? = nil,   // Legacy, ignored
        imageName: String? = nil,
        imageURL: URL? = nil,
        directURL: URL? = nil,
        amazonURL: URL? = nil,
        amazonMensURL: URL? = nil,
        amazonWomensURL: URL? = nil,
        badgeText: String? = nil,
        productBadge: KitProductBadge? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.category = category
        self.brand = brand
        self.model = model
        self.description = description
        self.strategicBenefit = strategicBenefit
        self.imageName = imageName
        self.imageURL = imageURL
        self.directURL = directURL
        self.amazonURL = amazonURL
        self.amazonMensURL = amazonMensURL
        self.amazonWomensURL = amazonWomensURL
        self.badgeText = badgeText
        self.productBadge = productBadge
        self.isPinned = isPinned
    }

    /// Resolves the effective badge type for display
    /// Priority: productBadge > badgeText inference > description inference > Editor's Pick fallback
    var effectiveBadge: KitProductBadge {
        // If explicit badge type is set, use it
        if let badge = productBadge {
            return badge
        }

        // Infer from legacy badgeText if present
        if let text = badgeText?.lowercased() {
            if text.contains("best value") || text.contains("value") {
                return .bestValue
            } else if text.contains("most popular") || text.contains("popular") || text.contains("top seller") {
                return .mostPopular
            } else if text.contains("editor") || text.contains("pick") {
                return .editorsPick
            }
        }

        // Infer from description field (common pattern in product database)
        let descLower = description.lowercased()
        if descLower.contains("best value") || descLower == "value" {
            return .bestValue
        } else if descLower.contains("most popular") || descLower == "popular" || descLower.contains("top seller") {
            return .mostPopular
        } else if descLower.contains("editor") || descLower.contains("pick") {
            return .editorsPick
        }

        // Default fallback: Editor's Pick
        return .editorsPick
    }
    
    /// Returns the best URL for this product, prioritizing direct URLs over Amazon
    func productURL(affiliateTag: String) -> URL? {
        // Prefer direct manufacturer/retailer links
        if let direct = directURL {
            return direct
        }
        // Fall back to Amazon with affiliate tag
        if let amazon = amazonURL {
            // Append affiliate tag if not already present
            var components = URLComponents(url: amazon, resolvingAgainstBaseURL: false)
            var queryItems = components?.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "tag" }) {
                queryItems.append(URLQueryItem(name: "tag", value: affiliateTag))
                components?.queryItems = queryItems
            }
            return components?.url ?? amazon
        }
        return nil
    }
}
