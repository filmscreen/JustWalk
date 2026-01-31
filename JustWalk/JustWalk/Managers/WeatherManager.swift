//
//  WeatherManager.swift
//  JustWalk
//
//  Fetches current weather conditions for contextual Smart Walk Card enhancements.
//  Weather is context, not content — only shown when pleasant.
//

import Combine
import CoreLocation
import Foundation
import WeatherKit

@MainActor
final class WeatherManager: NSObject, ObservableObject {
    static let shared = WeatherManager()

    // MARK: - Published State

    @Published private(set) var currentTemp: Int?  // User's preferred unit (F or C), rounded
    @Published private(set) var condition: WeatherCondition?
    @Published private(set) var isPleasant: Bool = false
    @Published private(set) var lastFetchTime: Date?

    // MARK: - Private

    private let weatherService = WeatherService.shared
    private let cacheDuration: TimeInterval = 1800 // 30 minutes
    private var locationManager: CLLocationManager?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    // MARK: - Weather Condition (Simplified)

    enum WeatherCondition {
        case clear
        case cloudy
        case rain
        case snow
        case extreme
        case unknown
    }

    private override init() {
        super.init()
    }

    // MARK: - Fetch Weather

    func fetchWeather(for location: CLLocation) async {
        do {
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather

            // Get temperature in user's preferred unit
            let useMetric = PersistenceManager.shared.cachedUseMetric
            let temp: Int
            if useMetric {
                temp = Int(current.temperature.converted(to: .celsius).value.rounded())
            } else {
                temp = Int(current.temperature.converted(to: .fahrenheit).value.rounded())
            }
            self.currentTemp = temp

            // Map WeatherKit condition to our simplified enum
            self.condition = mapCondition(current.condition)

            // Determine if weather is pleasant for walking
            self.isPleasant = calculateIsPleasant(tempF: fahrenheitTemp(from: current.temperature), condition: self.condition)

            self.lastFetchTime = Date()

        } catch {
            // Fail silently — weather is enhancement, not core functionality
            print("WeatherKit error: \(error.localizedDescription)")
            self.currentTemp = nil
            self.condition = .unknown
            self.isPleasant = false
        }
    }

    /// Check if we should fetch (respects 30-minute cache)
    func shouldFetch() -> Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch) >= cacheDuration
    }

    /// Convenience method: fetch weather using current location (if available)
    func fetchWeatherIfNeeded() async {
        guard shouldFetch() else { return }

        // Try to get location (reuses app's location authorization)
        guard let location = await getCurrentLocation() else {
            // No location available — fail silently
            return
        }

        await fetchWeather(for: location)
    }

    /// Get current location using a one-shot request
    private func getCurrentLocation() async -> CLLocation? {
        // Check authorization status
        let manager = CLLocationManager()
        let status = manager.authorizationStatus

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            // No location permission — fail silently
            return nil
        }

        // Use last known location if available and recent (within 10 minutes)
        if let lastLocation = manager.location,
           Date().timeIntervalSince(lastLocation.timestamp) < 600 {
            return lastLocation
        }

        // Request a one-time location update
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer
            self.locationManager?.requestLocation()

            // Timeout after 5 seconds
            Task {
                try? await Task.sleep(for: .seconds(5))
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(returning: nil)
                    self.locationContinuation = nil
                    self.locationManager = nil
                }
            }
        }
    }

    // MARK: - Weather Phrase Generation

    /// Returns a weather phrase if conditions are pleasant, otherwise nil
    func weatherPhrase() -> String? {
        guard isPleasant, let temp = currentTemp, let condition = condition else {
            return nil
        }

        let useMetric = PersistenceManager.shared.cachedUseMetric
        let tempString = "\(temp)°"

        // Vary phrasing based on condition
        let phrases: [String]
        switch condition {
        case .clear:
            phrases = [
                "\(tempString) and clear.",
                "\(tempString) and sunny.",
                "Beautiful out — \(tempString).",
                "\(tempString) with clear skies."
            ]
        case .cloudy:
            phrases = [
                "\(tempString) and mild.",
                "Nice out — \(tempString).",
                "\(tempString) with calm skies.",
                "Pleasant \(tempString) outside."
            ]
        default:
            return nil
        }

        // Use a deterministic selection based on the hour (so it doesn't change randomly during the day)
        let hour = Calendar.current.component(.hour, from: Date())
        let index = hour % phrases.count
        return phrases[index]
    }

    // MARK: - Private Helpers

    private func mapCondition(_ condition: WeatherKit.WeatherCondition) -> WeatherCondition {
        switch condition {
        case .clear, .mostlyClear, .partlyCloudy:
            return .clear
        case .cloudy, .mostlyCloudy:
            return .cloudy
        case .rain, .heavyRain, .drizzle, .sunShowers:
            return .rain
        case .snow, .heavySnow, .flurries, .sleet, .freezingRain, .freezingDrizzle, .wintryMix, .blizzard:
            return .snow
        case .hot, .frigid, .tropicalStorm, .hurricane, .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .hail:
            return .extreme
        default:
            // Windy, haze, smoky, breezy, foggy etc. — treat as unknown (not pleasant)
            return .unknown
        }
    }

    /// Always use Fahrenheit for pleasant calculation (45-85°F range)
    private func fahrenheitTemp(from temperature: Measurement<UnitTemperature>) -> Int {
        Int(temperature.converted(to: .fahrenheit).value.rounded())
    }

    private func calculateIsPleasant(tempF: Int, condition: WeatherCondition?) -> Bool {
        guard let condition = condition else { return false }

        // Pleasant = 45-85°F AND clear or cloudy (not rain/snow/extreme)
        let tempIsPleasant = tempF >= 45 && tempF <= 85
        let conditionIsPleasant = condition == .clear || condition == .cloudy

        return tempIsPleasant && conditionIsPleasant
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
            self.locationManager = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location failed — fail silently
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
            self.locationManager = nil
        }
    }
}
