//
//  RecommendedProduct.swift
//  Just Walk
//
//  Product recommendation data model for affiliate integration.
//

import Foundation

/// Platform for affiliate link generation
enum AffiliatePlatform: String, Codable {
    case amazon
    case impact
}

/// A recommended product for gear insights
struct RecommendedProduct: Identifiable, Codable {
    let id: String           // e.g., "hoka-bondi-8"
    let category: String     // e.g., "running_shoes", "walking_pad"
    let brand: String
    let model: String
    let asin: String?        // Amazon Standard Identification Number
    let impactId: String?    // Impact.com product ID
    let description: String
    let imageURL: URL?
    
    /// Generate affiliate link for the given platform
    func affiliateURL(platform: AffiliatePlatform, affiliateTag: String) -> URL? {
        switch platform {
        case .amazon:
            guard let asin = asin else { return nil }
            // Amazon deep link format (opens Amazon app if installed)
            return URL(string: "https://www.amazon.com/dp/\(asin)?tag=\(affiliateTag)")
        case .impact:
            guard let impactId = impactId else { return nil }
            return URL(string: "https://goto.target.com/c/\(affiliateTag)/\(impactId)")
        }
    }
}
