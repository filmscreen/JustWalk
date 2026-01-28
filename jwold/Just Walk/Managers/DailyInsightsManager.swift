//
//  DailyInsightsManager.swift
//  Just Walk
//
//  Created by Just Walk Team.
//

import Foundation
import SwiftUI
import Combine

/// Manages the daily rotation of "Level Up" insights.
/// Ensures 3 unique insights are shown each day.
final class DailyInsightsManager: ObservableObject {
    
    static let shared = DailyInsightsManager()
    
    @Published var todaysInsights: [LevelUpInsight] = []
    
    // UserDefaults keys
    private let kLastRefreshDate = "dailyInsightsLastRefreshDate"
    private let kTodaysInsightIDs = "dailyInsightsIDs" // Stores IDs (titles if no ID, but we generated UUIDs in struct)
    // Actually, persistence of UUIDs is tricky if we recreate the array every launch.
    // The `LevelUpInsight` struct has a UUID equal to `UUID()`, which regenerates on init.
    // We should persist INDICES or TITLES to be stable. Titles are stable in the static list.
    
    private init() {
        refreshInsightsIfNeeded()
    }
    
    func refreshInsightsIfNeeded() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        
        let lastRefresh = defaults.double(forKey: kLastRefreshDate)
        let lastDate = Date(timeIntervalSince1970: lastRefresh)
        
        // If it's a new day (or first launch)
        if !calendar.isDateInToday(lastDate) {
            rotateInsights()
        } else {
            // Load existing
            loadPersistedInsights()
        }
    }
    
    /// Debug method to force a new set of insights
    func forceRefresh() {
        rotateInsights()
    }
    
    private func rotateInsights() {
        let all = LevelUpDatabase.allInsights
        guard !all.isEmpty else { return }
        
        // Pick 10 random unique indices
        var selectedIndices: Set<Int> = []
        while selectedIndices.count < 10 && selectedIndices.count < all.count {
            selectedIndices.insert(Int.random(in: 0..<all.count))
        }
        
        let newInsights = selectedIndices.map { all[$0] }
        self.todaysInsights = newInsights
        
        // Persist titles (since UUIDs might change if struct is re-inited)
        let titles = newInsights.map { $0.title }
        UserDefaults.standard.set(titles, forKey: kTodaysInsightIDs)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: kLastRefreshDate)
    }
    
    private func loadPersistedInsights() {
        guard let savedTitles = UserDefaults.standard.stringArray(forKey: kTodaysInsightIDs) else {
            rotateInsights()
            return
        }
        
        let all = LevelUpDatabase.allInsights
        // Filter finding by title
        let loaded = savedTitles.compactMap { title in
            all.first(where: { $0.title == title })
        }
        
        if loaded.count == 10 {
             self.todaysInsights = loaded
        } else {
            // Fallback if data mismatch
            rotateInsights()
        }
    }
}
