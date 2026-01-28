//
//  DistanceContextManager.swift
//  Just Walk
//
//  Converts total miles walked into fun, real-world comparisons.
//  "You've walked the length of Manhattan!" beats "13.4 miles" any day.
//

import Foundation

// MARK: - Distance Landmark

struct DistanceLandmark {
    let name: String
    let miles: Double
    let emoji: String
}

// MARK: - Distance Context Manager

final class DistanceContextManager {

    static let shared = DistanceContextManager()

    private init() {}

    // MARK: - The Landmark Database (sorted by distance)

    private let landmarks: [DistanceLandmark] = [
        // Micro Distances (1-3 miles) - Great for short streaks
        DistanceLandmark(name: "Statue of Liberty loop", miles: 1.2, emoji: "🗽"),
        DistanceLandmark(name: "Eiffel Tower to Arc de Triomphe", miles: 1.5, emoji: "🇫🇷"),
        DistanceLandmark(name: "Golden Gate Bridge", miles: 1.7, emoji: "🌉"),
        DistanceLandmark(name: "Big Ben to Tower Bridge", miles: 2.0, emoji: "🇬🇧"),
        DistanceLandmark(name: "Sydney Opera House loop", miles: 2.2, emoji: "🎭"),
        DistanceLandmark(name: "Brooklyn Bridge round trip", miles: 2.4, emoji: "🌆"),
        DistanceLandmark(name: "Alcatraz Island ferry + walk", miles: 2.8, emoji: "🔒"),

        // Short Distances (3-5 miles)
        DistanceLandmark(name: "Times Square to Brooklyn Bridge", miles: 3.0, emoji: "🌃"),
        DistanceLandmark(name: "Colosseum to Vatican", miles: 3.2, emoji: "🏛️"),
        DistanceLandmark(name: "Disneyland Park perimeter", miles: 3.5, emoji: "🏰"),
        DistanceLandmark(name: "Hollywood Sign hike", miles: 3.8, emoji: "🎬"),
        DistanceLandmark(name: "Buckingham Palace to Big Ben x2", miles: 4.0, emoji: "👑"),
        DistanceLandmark(name: "Golden Gate Park length", miles: 4.2, emoji: "🌲"),
        DistanceLandmark(name: "Washington Monument to Lincoln Memorial x2", miles: 4.5, emoji: "🏛️"),
        DistanceLandmark(name: "French Quarter loop x2", miles: 4.8, emoji: "🎺"),

        // Medium Short Distances (5-7 miles)
        DistanceLandmark(name: "Santorini caldera walk", miles: 5.0, emoji: "🇬🇷"),
        DistanceLandmark(name: "Boston Freedom Trail x2", miles: 5.2, emoji: "🔔"),
        DistanceLandmark(name: "Acropolis to Temple of Zeus x3", miles: 5.5, emoji: "🏛️"),
        DistanceLandmark(name: "Miami Beach shoreline", miles: 5.8, emoji: "🏖️"),
        DistanceLandmark(name: "Central Park loop", miles: 6.0, emoji: "🌳"),
        DistanceLandmark(name: "10K race", miles: 6.2, emoji: "🏃"),
        DistanceLandmark(name: "Amsterdam canal loop", miles: 6.5, emoji: "🚲"),
        DistanceLandmark(name: "Waikiki Beach to Diamond Head", miles: 6.8, emoji: "🌺"),

        // Medium Distances (7-9 miles)
        DistanceLandmark(name: "Grand Canyon South Rim", miles: 7.0, emoji: "🏜️"),
        DistanceLandmark(name: "Niagara Falls trail", miles: 7.5, emoji: "💦"),
        DistanceLandmark(name: "Lake Tahoe shoreline segment", miles: 7.8, emoji: "🏔️"),
        DistanceLandmark(name: "San Francisco waterfront", miles: 8.0, emoji: "🌁"),
        DistanceLandmark(name: "Chicago Lakefront segment", miles: 8.2, emoji: "🌆"),
        DistanceLandmark(name: "Venice Beach to Santa Monica", miles: 8.5, emoji: "🏖️"),
        DistanceLandmark(name: "National Mall round trip", miles: 9.0, emoji: "🇺🇸"),
        DistanceLandmark(name: "Hyde Park perimeter x2", miles: 9.2, emoji: "🌳"),
        DistanceLandmark(name: "15K race", miles: 9.3, emoji: "🏃"),
        DistanceLandmark(name: "Barcelona beach to Sagrada Familia", miles: 9.5, emoji: "🇪🇸"),

        // Short Distances (10-15 miles)
        DistanceLandmark(name: "Vatican City x100", miles: 10.0, emoji: "⛪"),
        DistanceLandmark(name: "Yosemite Valley loop", miles: 10.5, emoji: "🦌"),
        DistanceLandmark(name: "Las Vegas Strip x2", miles: 11.0, emoji: "🎰"),
        DistanceLandmark(name: "Great Wall segment", miles: 11.5, emoji: "🐉"),
        DistanceLandmark(name: "Machu Picchu circuit", miles: 11.8, emoji: "🦙"),
        DistanceLandmark(name: "White House perimeter x100", miles: 12.0, emoji: "🏛️"),
        DistanceLandmark(name: "20K race", miles: 12.4, emoji: "🏃"),
        DistanceLandmark(name: "San Diego Gaslamp to La Jolla", miles: 12.5, emoji: "🌴"),
        DistanceLandmark(name: "Tokyo Shibuya to Senso-ji x2", miles: 13.0, emoji: "🗼"),
        DistanceLandmark(name: "Half Marathon", miles: 13.1, emoji: "🥇"),
        DistanceLandmark(name: "length of Manhattan", miles: 13.4, emoji: "🗽"),
        DistanceLandmark(name: "Malibu coastline", miles: 13.5, emoji: "🏄"),
        DistanceLandmark(name: "Cape Town waterfront to Table Mountain", miles: 14.0, emoji: "🦁"),
        DistanceLandmark(name: "Dubrovnik city walls x5", miles: 14.2, emoji: "🏰"),
        DistanceLandmark(name: "NYC High Line x10", miles: 14.5, emoji: "🌿"),
        DistanceLandmark(name: "Portland waterfront loop x2", miles: 14.8, emoji: "🌲"),
        DistanceLandmark(name: "Hadrian's Wall width", miles: 15.0, emoji: "🧱"),
        DistanceLandmark(name: "Edinburgh Royal Mile x10", miles: 15.0, emoji: "🏴󠁧󠁢󠁳󠁣󠁴󠁿"),
        DistanceLandmark(name: "Hollywood Sign hike x3", miles: 16.0, emoji: "🎬"),
        DistanceLandmark(name: "SF to Oakland via bridge", miles: 17.0, emoji: "🌁"),
        DistanceLandmark(name: "width of Paris", miles: 18.0, emoji: "🗼"),
        DistanceLandmark(name: "Alcatraz Island x20", miles: 19.0, emoji: "🔒"),

        // Distances (20-40 miles)
        DistanceLandmark(name: "English Channel swim", miles: 21.0, emoji: "🏊"),
        DistanceLandmark(name: "Central Park x4", miles: 22.0, emoji: "🌳"),
        DistanceLandmark(name: "Berlin Wall length", miles: 23.5, emoji: "🧱"),
        DistanceLandmark(name: "Niagara Falls gorge", miles: 24.0, emoji: "💦"),
        DistanceLandmark(name: "Pyramids of Giza x10", miles: 25.0, emoji: "🔺"),
        DistanceLandmark(name: "Marathon", miles: 26.2, emoji: "🏃"),
        DistanceLandmark(name: "across Monaco x6", miles: 27.0, emoji: "👑"),
        DistanceLandmark(name: "Colosseum x50", miles: 28.0, emoji: "🏟️"),
        DistanceLandmark(name: "Sydney Harbour x3", miles: 29.0, emoji: "🦘"),
        DistanceLandmark(name: "Danube Delta", miles: 30.0, emoji: "🐟"),
        DistanceLandmark(name: "length of Singapore", miles: 31.0, emoji: "🦁"),
        DistanceLandmark(name: "Mount Fuji trail roundtrip", miles: 32.0, emoji: "🗻"),
        DistanceLandmark(name: "Lake Geneva loop", miles: 33.0, emoji: "🇨🇭"),
        DistanceLandmark(name: "width of Hawaii", miles: 34.0, emoji: "🌺"),
        DistanceLandmark(name: "Hong Kong Island loop", miles: 35.0, emoji: "🏙️"),
        DistanceLandmark(name: "length of Loch Ness", miles: 36.0, emoji: "🦕"),
        DistanceLandmark(name: "Boston Marathon x1.5", miles: 37.0, emoji: "🦞"),
        DistanceLandmark(name: "Bermuda length x3", miles: 38.0, emoji: "🌊"),
        DistanceLandmark(name: "Lake Bled x20", miles: 39.0, emoji: "🏰"),
        DistanceLandmark(name: "width of Netherlands", miles: 40.0, emoji: "🌷"),

        // Distances (40-60 miles)
        DistanceLandmark(name: "Great Ocean Road segment", miles: 41.0, emoji: "🪨"),
        DistanceLandmark(name: "length of the Dead Sea", miles: 42.0, emoji: "🧂"),
        DistanceLandmark(name: "Monaco coastline x10", miles: 43.0, emoji: "🎲"),
        DistanceLandmark(name: "Tokyo Disney x20", miles: 44.0, emoji: "🎡"),
        DistanceLandmark(name: "Burj Khalifa height x80", miles: 45.0, emoji: "🏗️"),
        DistanceLandmark(name: "Grand Canyon rim-to-rim x2", miles: 46.0, emoji: "🏜️"),
        DistanceLandmark(name: "Amalfi Coast drive", miles: 47.0, emoji: "🍋"),
        DistanceLandmark(name: "Santorini coastline x5", miles: 48.0, emoji: "🇬🇷"),
        DistanceLandmark(name: "around Maui", miles: 49.0, emoji: "🐢"),
        DistanceLandmark(name: "Panama Canal", miles: 50.0, emoji: "🚢"),
        DistanceLandmark(name: "width of Wales", miles: 51.0, emoji: "🐑"),
        DistanceLandmark(name: "Lake Como x2", miles: 52.0, emoji: "⛵"),
        DistanceLandmark(name: "Costa del Sol", miles: 53.0, emoji: "☀️"),
        DistanceLandmark(name: "across Switzerland", miles: 54.0, emoji: "🧀"),
        DistanceLandmark(name: "Lake Tahoe length", miles: 55.0, emoji: "🏔️"),
        DistanceLandmark(name: "Isle of Skye loop", miles: 56.0, emoji: "🏴󠁧󠁢󠁳󠁣󠁴󠁿"),
        DistanceLandmark(name: "Bali east to west", miles: 57.0, emoji: "🌴"),
        DistanceLandmark(name: "Boston to Cape Cod", miles: 58.0, emoji: "🐋"),
        DistanceLandmark(name: "width of Costa Rica", miles: 59.0, emoji: "🦜"),
        DistanceLandmark(name: "Isle of Wight coastline", miles: 60.0, emoji: "🏝️"),

        // Distances (60-80 miles)
        DistanceLandmark(name: "length of Crete", miles: 61.0, emoji: "🏺"),
        DistanceLandmark(name: "Lake Garda x2", miles: 62.0, emoji: "🍷"),
        DistanceLandmark(name: "width of North Korea", miles: 63.0, emoji: "🗻"),
        DistanceLandmark(name: "Ring of Kerry (partial)", miles: 64.0, emoji: "🍀"),
        DistanceLandmark(name: "length of Long Island", miles: 65.0, emoji: "🗽"),
        DistanceLandmark(name: "across Tasmania", miles: 66.0, emoji: "🦘"),
        DistanceLandmark(name: "around Oahu", miles: 67.0, emoji: "🏄"),
        DistanceLandmark(name: "length of Cyprus", miles: 68.0, emoji: "🏺"),
        DistanceLandmark(name: "NYC to Philadelphia", miles: 69.0, emoji: "🔔"),
        DistanceLandmark(name: "width of Scotland", miles: 70.0, emoji: "🏴󠁧󠁢󠁳󠁣󠁴󠁿"),
        DistanceLandmark(name: "Lake Balaton x2", miles: 71.0, emoji: "🇭🇺"),
        DistanceLandmark(name: "width of Slovenia", miles: 72.0, emoji: "⛰️"),
        DistanceLandmark(name: "Loire Valley wine route", miles: 73.0, emoji: "🍇"),
        DistanceLandmark(name: "Corsica (partial)", miles: 74.0, emoji: "🇫🇷"),
        DistanceLandmark(name: "San Diego to LA", miles: 75.0, emoji: "🏄"),
        DistanceLandmark(name: "Ibiza coastline x3", miles: 76.0, emoji: "🎶"),
        DistanceLandmark(name: "Lake Titicaca (partial)", miles: 77.0, emoji: "🦙"),
        DistanceLandmark(name: "width of Austria", miles: 78.0, emoji: "🎿"),
        DistanceLandmark(name: "across Jamaica", miles: 79.0, emoji: "🎷"),
        DistanceLandmark(name: "Hadrian's Wall full length", miles: 80.0, emoji: "🏰"),

        // Distances (80-100 miles)
        DistanceLandmark(name: "width of Belgium", miles: 85.0, emoji: "🍫"),
        DistanceLandmark(name: "Cinque Terre x10", miles: 90.0, emoji: "🍝"),
        DistanceLandmark(name: "around Majorca", miles: 95.0, emoji: "🌞"),
        DistanceLandmark(name: "length of Puerto Rico", miles: 100.0, emoji: "🌴"),

        // Long Distances (100-500 miles)
        DistanceLandmark(name: "width of Lake Michigan", miles: 118.0, emoji: "🌊"),
        DistanceLandmark(name: "width of Ireland", miles: 174.0, emoji: "🍀"),
        DistanceLandmark(name: "Grand Canyon x5", miles: 277.0, emoji: "🏜️"),
        DistanceLandmark(name: "length of Florida", miles: 447.0, emoji: "🐊"),
        DistanceLandmark(name: "Colorado Trail", miles: 486.0, emoji: "⛰️"),
        DistanceLandmark(name: "Camino de Santiago", miles: 500.0, emoji: "🐚"),

        // Epic Distances (500-2000 miles)
        DistanceLandmark(name: "length of Great Britain", miles: 600.0, emoji: "🇬🇧"),
        DistanceLandmark(name: "length of California", miles: 770.0, emoji: "🌴"),
        DistanceLandmark(name: "Land's End to John o' Groats", miles: 874.0, emoji: "🏴󠁧󠁢󠁳󠁣󠁴󠁿"),
        DistanceLandmark(name: "length of Japan", miles: 1869.0, emoji: "🗾"),

        // Legendary Distances (2000+ miles)
        DistanceLandmark(name: "Appalachian Trail", miles: 2190.0, emoji: "🥾"),
        DistanceLandmark(name: "Route 66", miles: 2448.0, emoji: "🛣️"),
        DistanceLandmark(name: "Pacific Crest Trail", miles: 2650.0, emoji: "🦌"),
        DistanceLandmark(name: "width of the USA", miles: 2800.0, emoji: "🦅"),
        DistanceLandmark(name: "length of the Nile", miles: 4132.0, emoji: "🐊"),
        DistanceLandmark(name: "diameter of Mars", miles: 4212.0, emoji: "🔴"),
        DistanceLandmark(name: "Great Wall of China", miles: 5500.0, emoji: "🐉"),
        DistanceLandmark(name: "Trans-Siberian Railway", miles: 5772.0, emoji: "🚂"),
        DistanceLandmark(name: "Moon's circumference", miles: 6784.0, emoji: "🌙"),
        DistanceLandmark(name: "Earth's circumference", miles: 24901.0, emoji: "🌍"),
    ].sorted { $0.miles < $1.miles }

    // MARK: - Public API

    /// Returns a punchy, fun comparison for the user's total miles walked.
    /// - Parameter userMiles: The user's total miles walked.
    /// - Returns: A motivational string comparing their distance to a real-world landmark.
    func getComparison(for userMiles: Double) -> String {
        // Edge case: user hasn't walked enough yet
        guard userMiles >= 1.0, let smallest = landmarks.first else {
            return "Keep walking! The Golden Gate Bridge awaits 🌉"
        }

        // If user hasn't hit the smallest landmark yet
        if userMiles < smallest.miles {
            let remaining = smallest.miles - userMiles
            return String(format: "%.1f more miles to the %@ %@", remaining, smallest.name, smallest.emoji)
        }

        // Find the largest landmark the user has surpassed
        var bestLandmark = smallest
        for landmark in landmarks {
            if userMiles >= landmark.miles {
                bestLandmark = landmark
            } else {
                break
            }
        }

        // Calculate how many times they've walked it
        let multiplier = Int(userMiles / bestLandmark.miles)

        if multiplier > 1 {
            // Pluralize name if needed
            let pluralName = pluralize(bestLandmark.name, count: multiplier)
            return "That's \(multiplier)x \(pluralName) \(bestLandmark.emoji)"
        } else {
            return "You've walked the \(bestLandmark.name)! \(bestLandmark.emoji)"
        }
    }

    /// Returns the next milestone landmark the user is working towards.
    /// - Parameter userMiles: The user's current total miles.
    /// - Returns: A tuple with the next landmark and miles remaining, or nil if they've conquered Earth.
    func getNextMilestone(for userMiles: Double) -> (landmark: DistanceLandmark, remaining: Double)? {
        for landmark in landmarks {
            if userMiles < landmark.miles {
                return (landmark, landmark.miles - userMiles)
            }
        }
        return nil // They've walked the Earth!
    }

    /// Returns a natural, approximate comparison for streak summaries.
    /// Always uses consistent phrasing: "That's about/almost/just over the length of..."
    /// Randomly selects from similar-distance landmarks for variety.
    /// - Parameter userMiles: The user's miles for the period.
    /// - Returns: A natural language comparison string.
    func getApproximateComparison(for userMiles: Double) -> String {
        guard userMiles >= 1.0 else {
            return "Keep going!"
        }

        // Find all landmarks within ±15% of user's distance for variety
        let tolerance = 0.15
        let matchingLandmarks = landmarks.filter { landmark in
            let ratio = userMiles / landmark.miles
            return ratio >= (1 - tolerance) && ratio <= (1 + tolerance)
        }

        // Pick a random one if multiple matches, otherwise find closest
        let landmark: DistanceLandmark
        if !matchingLandmarks.isEmpty {
            landmark = matchingLandmarks.randomElement()!
        } else {
            // Fall back to closest landmark
            guard let closest = landmarks.min(by: { abs($0.miles - userMiles) < abs($1.miles - userMiles) }) else {
                return "That's \(String(format: "%.0f", userMiles)) miles"
            }
            landmark = closest
        }

        let ratio = userMiles / landmark.miles

        // Consistent phrasing: "That's about/almost/just over the [landmark name]..."
        switch ratio {
        case ..<0.80:
            // Much less - find a smaller landmark
            if let smallerLandmark = findClosestSmallerLandmark(for: userMiles) {
                let smallerRatio = userMiles / smallerLandmark.miles
                if smallerRatio >= 0.90 && smallerRatio <= 1.10 {
                    return "That's about the \(smallerLandmark.name) \(smallerLandmark.emoji)"
                } else if smallerRatio > 1.10 {
                    return "That's just over the \(smallerLandmark.name) \(smallerLandmark.emoji)"
                } else {
                    return "That's almost the \(smallerLandmark.name) \(smallerLandmark.emoji)"
                }
            }
            return "That's almost the \(landmark.name) \(landmark.emoji)"
        case 0.80..<0.90:
            return "That's almost the \(landmark.name) \(landmark.emoji)"
        case 0.90..<1.10:
            return "That's about the \(landmark.name) \(landmark.emoji)"
        case 1.10..<1.30:
            return "That's just over the \(landmark.name) \(landmark.emoji)"
        default:
            // Much more - use multiplier
            let multiplier = Int(ratio)
            if multiplier >= 2 {
                return "That's about \(multiplier)x the \(landmark.name) \(landmark.emoji)"
            }
            return "That's about the \(landmark.name) \(landmark.emoji)"
        }
    }

    /// Returns the appropriate article ("a" or "the") for a landmark name.
    private func articleFor(_ name: String) -> String {
        // Use "a/an" for these landmarks
        let useIndefiniteArticle = ["Marathon", "Half Marathon"]
        if useIndefiniteArticle.contains(name) {
            return "a"
        }
        return "the"
    }

    /// Finds the closest landmark that's smaller than the user's miles.
    private func findClosestSmallerLandmark(for userMiles: Double) -> DistanceLandmark? {
        var best: DistanceLandmark?
        for landmark in landmarks {
            if landmark.miles <= userMiles {
                best = landmark
            } else {
                break
            }
        }
        return best
    }

    // MARK: - Private Helpers

    private func pluralize(_ name: String, count: Int) -> String {
        // Handle common cases
        if name.hasSuffix("s") || name.hasSuffix("x") || count == 1 {
            return name
        }

        // Special cases that shouldn't be pluralized
        let noPlural = ["Panama Canal", "English Channel", "Appalachian Trail", "Route 66",
                        "Pacific Crest Trail", "Colorado Trail", "Camino de Santiago"]
        if noPlural.contains(where: { name.contains($0) }) {
            return name
        }

        return name + "s"
    }
}
