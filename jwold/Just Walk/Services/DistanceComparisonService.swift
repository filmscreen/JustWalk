//
//  DistanceComparisonService.swift
//  Just Walk
//
//  Provides fun, relatable distance comparisons with random selection and caching.
//

import Foundation

final class DistanceComparisonService {
    static let shared = DistanceComparisonService()

    private init() {}

    // MARK: - Distance Comparisons by Range

    private static let comparisons: [(minMiles: Double, maxMiles: Double, texts: [String])] = [
        (0.1, 0.5, [
            "That's about 2 football fields 🏈",
            "That's a lap around a city block",
            "That's the length of the Titanic",
            "That's across a cruise ship deck 🚢"
        ]),
        (0.5, 1, [
            "That's 4 laps around a track 🏃",
            "That's across the Golden Gate Bridge (one way)",
            "That's the Las Vegas Strip, end to end 🎰",
            "That's about 10 city blocks"
        ]),
        (1, 2, [
            "That's across Central Park 🌳",
            "That's the length of the National Mall",
            "That's about 20 minutes of walking",
            "That's across Disney's Magic Kingdom 🏰"
        ]),
        (2, 5, [
            "That's the San Francisco cable car route 🚋",
            "That's across the Brooklyn Bridge and back",
            "That's a 5K race distance 🏅",
            "That's about the length of Venice Beach boardwalk",
            "That's the Champs-Élysées, 4 times over 🇫🇷"
        ]),
        (5, 10, [
            "That's across Manhattan, north to south 🗽",
            "That's the width of San Francisco",
            "That's a solid morning adventure",
            "That's London's Circle Line, halfway around 🇬🇧",
            "That's roughly across Washington D.C."
        ]),
        (10, 15, [
            "That's a half marathon 🏃‍♂️",
            "That's across the entire island of Bermuda",
            "That's Miami Beach to Downtown and back 🌴",
            "That's the length of Lake Tahoe"
        ]),
        (15, 26, [
            "That's the width of Paris 🗼",
            "That's Singapore, coast to coast 🇸🇬",
            "That's almost a full marathon!",
            "That's across the Grand Canyon (rim to rim)",
            "That's the entire island of Manhattan, twice 🚕"
        ]),
        (26, 50, [
            "That's a full marathon 🎉",
            "That's across Rhode Island",
            "That's London to Brighton 🇬🇧",
            "That's the English Channel (if you could walk on water) 🌊",
            "That's the length of Lake Michigan's shoreline drive"
        ]),
        (50, 100, [
            "That's the length of the Panama Canal 🚢",
            "That's LA to San Diego 🌴",
            "That's Paris to the Champagne region 🥂",
            "That's about the length of Long Island",
            "That's Boston's Freedom Trail, 16 times over"
        ]),
        (100, 200, [
            "That's London to Birmingham 🇬🇧",
            "That's New York to Philadelphia 🚂",
            "That's the Oregon coastline",
            "That's across Switzerland 🇨🇭",
            "That's Tokyo to Mount Fuji and back 🗻"
        ]),
        (200, 300, [
            "That's New York to Boston 🚗",
            "That's Las Vegas to Los Angeles 🎰",
            "That's the length of Hawaii's Big Island coastline 🌺",
            "That's Amsterdam to Paris 🇳🇱"
        ]),
        (300, 500, [
            "That's LA to San Francisco 🌉",
            "That's Chicago to Detroit",
            "That's the length of Cuba 🇨🇺",
            "That's London to Edinburgh 🏴󠁧󠁢󠁳󠁣󠁴󠁿",
            "That's the Tour de France... one stage 🚴"
        ]),
        (500, 750, [
            "That's the California coastline 🌊",
            "That's Denver to Dallas",
            "That's Paris to Barcelona 🇪🇸",
            "That's Tokyo to Osaka, round trip 🇯🇵",
            "That's across Texas (the short way)"
        ]),
        (750, 1000, [
            "That's New York to Chicago 🏙️",
            "That's Seattle to LA",
            "That's London to Rome 🇮🇹",
            "That's the Appalachian Trail, halfway through 🥾"
        ]),
        (1000, 1500, [
            "That's Miami to New York 🗽",
            "That's the entire UK, top to bottom 🇬🇧",
            "That's Paris to Moscow (halfway) 🇷🇺",
            "That's Route 66, one third done"
        ]),
        (1500, 2000, [
            "That's coast to coast across Australia 🇦🇺",
            "That's LA to Dallas to Houston",
            "That's the Appalachian Trail, end to end 🥾",
            "That's Cairo to Cape Town (you're 25% there)"
        ]),
        (2000, 3000, [
            "That's New York to LA 🇺🇸",
            "That's Route 66, complete 🛣️",
            "That's London to New York (if you could walk on water)",
            "That's the width of the United States",
            "That's the Pacific Crest Trail, end to end 🏔️"
        ]),
        (3000, Double.infinity, [
            "That's crossing the Atlantic Ocean 🌊",
            "That's London to New Delhi 🇮🇳",
            "That's the Silk Road (ancient traders are impressed)",
            "That's the Great Wall of China, end to end 🇨🇳",
            "You're basically Forrest Gump at this point 🏃"
        ])
    ]

    // MARK: - Cache Keys

    private let cacheKey = "cachedDistanceComparison"
    private let cacheRangeKey = "cachedDistanceRange"
    private let cacheStreakStartKey = "cachedDistanceStreakStart"

    // MARK: - Public API

    /// Returns a fun distance comparison, cached per streak and range
    func getComparison(for miles: Double, streakStartDate: Date?) -> String {
        // Check if we have a cached comparison for this streak
        if let cached = getCachedComparison(for: miles, streakStartDate: streakStartDate) {
            return cached
        }

        // Select new random comparison
        let comparison = selectRandomComparison(for: miles)

        // Cache it
        cacheComparison(comparison, miles: miles, streakStartDate: streakStartDate)

        return comparison
    }

    /// Clears the cached comparison (call when streak resets)
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheRangeKey)
        UserDefaults.standard.removeObject(forKey: cacheStreakStartKey)
    }

    // MARK: - Private Helpers

    private func selectRandomComparison(for miles: Double) -> String {
        // Handle very small distances
        if miles < 0.1 {
            return "Just getting started!"
        }

        // Find the matching range
        for range in Self.comparisons {
            if miles >= range.minMiles && miles < range.maxMiles {
                return range.texts.randomElement() ?? "Keep walking!"
            }
        }

        // Fallback for 3000+ miles (last range uses infinity)
        return Self.comparisons.last?.texts.randomElement() ?? "Legendary distance!"
    }

    private func getCachedComparison(for miles: Double, streakStartDate: Date?) -> String? {
        guard let cachedText = UserDefaults.standard.string(forKey: cacheKey),
              let cachedRange = UserDefaults.standard.string(forKey: cacheRangeKey),
              let cachedStreakStart = UserDefaults.standard.object(forKey: cacheStreakStartKey) as? Date else {
            return nil
        }

        // Check if streak start date matches (new streak = new comparison)
        if let streakStart = streakStartDate {
            let calendar = Calendar.current
            if !calendar.isDate(cachedStreakStart, inSameDayAs: streakStart) {
                return nil // New streak, need new comparison
            }
        }

        // Check if we're still in the same range
        let currentRange = getRangeKey(for: miles)
        if cachedRange != currentRange {
            return nil // Moved to new range, need new comparison
        }

        return cachedText
    }

    private func cacheComparison(_ text: String, miles: Double, streakStartDate: Date?) {
        UserDefaults.standard.set(text, forKey: cacheKey)
        UserDefaults.standard.set(getRangeKey(for: miles), forKey: cacheRangeKey)
        if let streakStart = streakStartDate {
            UserDefaults.standard.set(streakStart, forKey: cacheStreakStartKey)
        }
    }

    private func getRangeKey(for miles: Double) -> String {
        for range in Self.comparisons {
            if miles >= range.minMiles && miles < range.maxMiles {
                return "\(range.minMiles)-\(range.maxMiles)"
            }
        }
        return "3000+"
    }
}
