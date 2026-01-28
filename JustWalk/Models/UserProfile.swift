//
//  UserProfile.swift
//  JustWalk
//
//  Core data model for user profile
//

import Foundation

struct UserProfile: Codable, Equatable {
    var displayName: String
    var dailyStepGoal: Int // 1000–25000 in 500-step increments
    var useMetricUnits: Bool
    var hasCompletedOnboarding: Bool
    var hasSeenFirstWalkEducation: Bool
    var createdAt: Date
    var isPro: Bool
    var legacyBadges: [LegacyBadge]

    static let `default` = UserProfile(
        displayName: "",
        dailyStepGoal: 5000,
        useMetricUnits: false,
        hasCompletedOnboarding: false,
        hasSeenFirstWalkEducation: false,
        createdAt: Date(),
        isPro: false,
        legacyBadges: []
    )
}
