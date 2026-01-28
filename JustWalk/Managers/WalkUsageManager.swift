//
//  WalkUsageManager.swift
//  JustWalk
//
//  Centralized usage tracking for gated walk types (intervals + fat burn)
//

import Foundation
import Combine

@Observable
class WalkUsageManager: ObservableObject {
    static let shared = WalkUsageManager()

    var intervalUsage: IntervalUsageData
    var fatBurnUsage: FatBurnUsageData

    private let persistence = PersistenceManager.shared

    private init() {
        intervalUsage = PersistenceManager.shared.loadIntervalUsage()
        fatBurnUsage = PersistenceManager.shared.loadFatBurnUsage()
    }

    // MARK: - Queries

    func canStart(_ mode: WalkMode) -> Bool {
        switch mode {
        case .interval:
            return intervalUsage.canStartInterval
        case .fatBurn:
            return fatBurnUsage.canStartFatBurn
        case .free, .postMeal:
            return true
        }
    }

    /// Returns the number of remaining free sessions, or nil if unlimited (free walk / post-meal).
    func remainingFree(for mode: WalkMode) -> Int? {
        switch mode {
        case .interval:
            return intervalUsage.remainingFree
        case .fatBurn:
            return fatBurnUsage.remainingFree
        case .free, .postMeal:
            return nil
        }
    }

    // MARK: - Mutations

    func recordUsage(for mode: WalkMode) {
        switch mode {
        case .interval:
            intervalUsage.recordUsage()
            persistence.saveIntervalUsage(intervalUsage)
        case .fatBurn:
            fatBurnUsage.recordUsage()
            persistence.saveFatBurnUsage(fatBurnUsage)
        case .free, .postMeal:
            break
        }
    }

    /// Resets both trackers if the ISO week has rolled over.
    func refreshWeek() {
        intervalUsage.resetIfNewWeek()
        persistence.saveIntervalUsage(intervalUsage)

        fatBurnUsage.resetIfNewWeek()
        persistence.saveFatBurnUsage(fatBurnUsage)
    }
}
