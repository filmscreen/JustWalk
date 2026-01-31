//
//  LocationInsightsService.swift
//  JustWalk
//
//  One-time location detection + weekly distance insights using curated landmarks
//

import Foundation
import CoreLocation

// MARK: - Weekly Insight

struct WeeklyInsight {
    let dataLine: String     // "37 miles this week."
    let contextLine: String  // "That's across San Francisco."
}

// MARK: - Landmark Data Models

struct LandmarkEntry: Codable {
    let miles: Int
    let text: String
}

struct CityData: Codable {
    let name: String
    let landmarks: [LandmarkEntry]
}

struct LandmarkData: Codable {
    let cities: [String: CityData]
    let regions: [String: [LandmarkEntry]]
    let universal: [LandmarkEntry]
}

// MARK: - Location Insights Service

@Observable
class LocationInsightsService {
    static let shared = LocationInsightsService()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let userCity = "locationInsights_userCity"
        static let userRegion = "locationInsights_userRegion"
        static let detectionDone = "locationInsights_detectionDone"
    }

    private(set) var userCity: String? {
        get { defaults.string(forKey: Keys.userCity) }
        set { defaults.set(newValue, forKey: Keys.userCity) }
    }

    private(set) var userRegion: String? {
        get { defaults.string(forKey: Keys.userRegion) }
        set { defaults.set(newValue, forKey: Keys.userRegion) }
    }

    private(set) var detectionDone: Bool {
        get { defaults.bool(forKey: Keys.detectionDone) }
        set { defaults.set(newValue, forKey: Keys.detectionDone) }
    }

    private let landmarkData: LandmarkData

    private init() {
        landmarkData = Self.loadLandmarkData()
    }

    // MARK: - Load JSON

    private static func loadLandmarkData() -> LandmarkData {
        guard let url = Bundle.main.url(forResource: "LocationLandmarks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(LandmarkData.self, from: data) else {
            // Fallback: empty data with universal defaults
            return LandmarkData(cities: [:], regions: [:], universal: [
                LandmarkEntry(miles: 5, text: "a typical morning walk"),
                LandmarkEntry(miles: 10, text: "about 20,000 steps"),
                LandmarkEntry(miles: 26, text: "a full marathon distance"),
                LandmarkEntry(miles: 50, text: "about 100,000 steps"),
                LandmarkEntry(miles: 100, text: "nearly four marathons")
            ])
        }
        return decoded
    }

    // MARK: - One-Time Location Detection

    func detectLocationOnce() {
        guard !detectionDone else { return }

        let manager = CLLocationManager()
        guard let location = manager.location else { return }

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let placemark = placemarks?.first else { return }

            // Store city if we have landmark data for it
            if let city = placemark.locality?
                .lowercased()
                .replacingOccurrences(of: " ", with: "_"),
               self.landmarkData.cities[city] != nil {
                self.userCity = city
            }

            // Store region as fallback
            if let state = placemark.administrativeArea {
                self.userRegion = self.regionForState(state)
            }

            self.detectionDone = true
        }
    }

    // MARK: - Insight Generation

    func generateWeeklyInsight(weekSteps: Int) -> WeeklyInsight {
        let useMetric = PersistenceManager.shared.cachedUseMetric
        let miles = Double(weekSteps) / 2100.0
        let km = miles * 1.60934

        // Edge case: week just started
        if miles < 2 {
            return WeeklyInsight(
                dataLine: "Week just started.",
                contextLine: "Let's see where it goes."
            )
        }

        // Edge case: low step week
        if miles < 5 {
            let distanceText: String
            if useMetric {
                distanceText = "\(Int(km.rounded())) km so far."
            } else {
                distanceText = "\(Int(miles.rounded())) miles so far."
            }
            return WeeklyInsight(
                dataLine: distanceText,
                contextLine: "Every step counts."
            )
        }

        // Normal path
        let roundedMiles = Int(miles.rounded())
        let roundedKm = Int(km.rounded())

        let dataLine: String
        if useMetric {
            dataLine = "\(roundedKm) km this week."
        } else {
            dataLine = "\(roundedMiles) miles this week."
        }

        let contextLine = getContextLine(for: roundedMiles)

        return WeeklyInsight(dataLine: dataLine, contextLine: contextLine)
    }

    // MARK: - Context Line

    private func getContextLine(for miles: Int) -> String {
        // Try city-specific
        if let city = userCity,
           let cityData = landmarkData.cities[city],
           let landmark = findClosestLandmark(miles: miles, in: cityData.landmarks) {
            return "That's \(landmark.text)."
        }

        // Try regional
        if let region = userRegion,
           let regionLandmarks = landmarkData.regions[region],
           let landmark = findClosestLandmark(miles: miles, in: regionLandmarks) {
            let text = landmark.text
            if text.hasPrefix("a") || text.hasPrefix("an") {
                return "That's \(text)."
            }
            return "That's like \(text)."
        }

        // Fall back to universal
        if let landmark = findClosestLandmark(miles: miles, in: landmarkData.universal) {
            return "That's \(landmark.text)."
        }

        return "That's about \(miles * 2000) steps."
    }

    private func findClosestLandmark(miles: Int, in landmarks: [LandmarkEntry]) -> LandmarkEntry? {
        // Find the landmark closest to the given miles without exceeding it much
        landmarks
            .filter { $0.miles <= miles + 5 }
            .max(by: { $0.miles < $1.miles })
    }

    // MARK: - State → Region Mapping

    private func regionForState(_ state: String) -> String {
        let northeast: Set<String> = [
            "Maine", "New Hampshire", "Vermont", "Massachusetts", "Rhode Island",
            "Connecticut", "New York", "New Jersey", "Pennsylvania"
        ]
        let southeast: Set<String> = [
            "Delaware", "Maryland", "Virginia", "West Virginia", "Kentucky",
            "North Carolina", "South Carolina", "Tennessee", "Georgia",
            "Florida", "Alabama", "Mississippi", "Louisiana", "Arkansas"
        ]
        let midwest: Set<String> = [
            "Ohio", "Michigan", "Indiana", "Illinois", "Wisconsin",
            "Minnesota", "Iowa", "Missouri", "North Dakota", "South Dakota",
            "Nebraska", "Kansas"
        ]
        let southwest: Set<String> = [
            "Texas", "Oklahoma", "New Mexico", "Arizona"
        ]
        // Everything else falls to west
        if northeast.contains(state) { return "northeast" }
        if southeast.contains(state) { return "southeast" }
        if midwest.contains(state) { return "midwest" }
        if southwest.contains(state) { return "southwest" }
        return "west"
    }
}
