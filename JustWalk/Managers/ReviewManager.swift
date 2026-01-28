//
//  ReviewManager.swift
//  JustWalk
//
//  App Store review prompt manager
//

import Foundation
import StoreKit

@Observable
class ReviewManager {
    static let shared = ReviewManager()

    private let defaults = UserDefaults.standard
    private let walkCountKey = "review_totalWalkCount"
    private let hasRequestedKey = "review_hasRequested"

    var totalWalkCount: Int {
        didSet { defaults.set(totalWalkCount, forKey: walkCountKey) }
    }

    var hasRequestedReview: Bool {
        didSet { defaults.set(hasRequestedReview, forKey: hasRequestedKey) }
    }

    private init() {
        self.totalWalkCount = defaults.integer(forKey: walkCountKey)
        self.hasRequestedReview = defaults.bool(forKey: hasRequestedKey)
    }

    func recordWalk() {
        totalWalkCount += 1
    }

    func requestReviewIfEligible() {
        guard !hasRequestedReview else { return }

        let currentStreak = StreakManager.shared.streakData.currentStreak

        guard totalWalkCount >= 5, currentStreak >= 7 else { return }

        hasRequestedReview = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }

            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}
