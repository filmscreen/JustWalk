//
//  GearInsight.swift
//  Just Walk
//
//  Smart Gear recommendation based on user data.
//

import Foundation

/// Type of friction point that triggered the insight
enum InsightType: String, Codable {
    case shoeWall = "shoe_wall"      // 400 miles on shoes
    case deskTrap = "desk_trap"      // 40% below average for 3 days
}

/// A gear insight recommendation triggered by user data
struct GearInsight: Identifiable, Codable {
    let id: UUID
    let type: InsightType
    let headline: String
    let explanation: String
    let product: RecommendedProduct?
    let triggeredAt: Date
    var isDismissed: Bool = false
    
    init(
        id: UUID = UUID(),
        type: InsightType,
        headline: String,
        explanation: String,
        product: RecommendedProduct? = nil,
        triggeredAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.headline = headline
        self.explanation = explanation
        self.product = product
        self.triggeredAt = triggeredAt
    }
}
