//
//  FatBurnZoneManager.swift
//  JustWalk
//
//  Manages Fat Burn Zone state: zone calculation, HR zone status,
//  hysteresis to prevent flicker, and time-in-zone tracking.
//

import SwiftUI
import HealthKit
import Combine

@Observable
class FatBurnZoneManager: ObservableObject {

    // MARK: - Singleton

    static let shared = FatBurnZoneManager()

    // MARK: - Age & Zone

    @ObservationIgnored
    @AppStorage("userAge") var storedAge: Int?

    var zoneLow: Int = 0
    var zoneHigh: Int = 0
    var maxHR: Int = 0

    // MARK: - Active Session State

    var currentHR: Int = 0
    var zoneState: ZoneState = .inZone
    var timeInZoneSeconds: Int = 0
    var totalActiveSeconds: Int = 0

    // MARK: - Hysteresis

    /// Buffer to prevent rapid state changes at zone boundaries.
    /// If currently "in zone", HR must be 3+ bpm outside to exit.
    /// If currently "out of zone", HR must be 2+ bpm inside to re-enter.
    private let exitBuffer: Int = 3
    private let enterBuffer: Int = 2

    // MARK: - Zone State

    enum ZoneState: Equatable {
        case belowZone
        case inZone
        case aboveZone

        var label: String {
            switch self {
            case .belowZone: return "SPEED UP"
            case .inZone: return "IN THE ZONE"
            case .aboveZone: return "SLOW DOWN"
            }
        }

        var guidance: String? {
            switch self {
            case .belowZone: return "Pick up the pace"
            case .inZone: return nil
            case .aboveZone: return "Easy does it"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .belowZone: return Color(red: 0.2, green: 0.4, blue: 0.8) // Blue tint
            case .inZone: return Color(red: 0.2, green: 0.7, blue: 0.4)    // Green tint
            case .aboveZone: return Color(red: 0.9, green: 0.5, blue: 0.2) // Orange tint
            }
        }
    }

    // MARK: - Init

    private init() {
        recalculateZone()
    }

    // MARK: - Zone Calculation

    func recalculateZone() {
        guard let age = storedAge, age > 0, age < 120 else {
            maxHR = 185 // fallback (age 35)
            zoneLow = 111
            zoneHigh = 130
            return
        }
        maxHR = 220 - age
        zoneLow = Int(Double(maxHR) * 0.60)
        zoneHigh = Int(Double(maxHR) * 0.70)
    }

    static func calculateZone(for age: Int) -> (low: Int, high: Int, maxHR: Int) {
        let maxHR = 220 - age
        let low = Int(Double(maxHR) * 0.60)
        let high = Int(Double(maxHR) * 0.70)
        return (low, high, maxHR)
    }

    // MARK: - Age from HealthKit

    func fetchAgeFromHealthKit() async -> Int? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let healthStore = HKHealthStore()

        // Request authorization for date of birth
        guard let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) else {
            return nil
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [dobType])
            let dobComponents = try healthStore.dateOfBirthComponents()
            guard let dobDate = dobComponents.date else { return nil }
            let age = Calendar.current.dateComponents([.year], from: dobDate, to: Date()).year
            return age
        } catch {
            print("Failed to fetch DOB from HealthKit: \(error)")
            return nil
        }
    }

    // MARK: - Session Control

    func startSession() {
        currentHR = 0
        zoneState = .inZone
        timeInZoneSeconds = 0
        totalActiveSeconds = 0
        // Heart rate will come from Apple Watch via PhoneConnectivityManager
    }

    func stopSession() {
        currentHR = 0
    }

    /// Updates the current heart rate from Apple Watch.
    /// Call this when receiving heart rate data from WatchConnectivity.
    func updateHeartRate(_ bpm: Int) {
        currentHR = bpm
    }

    /// Called every second from the active view's timer to update HR state.
    /// Heart rate is updated via updateHeartRate(_:) from Apple Watch data.
    func tick() {
        totalActiveSeconds += 1

        // Update zone state with hysteresis (currentHR is set via updateHeartRate from Watch)
        updateZoneState()

        // Track time in zone
        if zoneState == .inZone {
            timeInZoneSeconds += 1
        }
    }

    // MARK: - Hysteresis Logic

    private func updateZoneState() {
        let hr = currentHR
        guard hr > 0 else { return }

        switch zoneState {
        case .inZone:
            // Only exit if HR is exitBuffer bpm outside the zone
            if hr < zoneLow - exitBuffer {
                zoneState = .belowZone
            } else if hr > zoneHigh + exitBuffer {
                zoneState = .aboveZone
            }

        case .belowZone:
            // Only re-enter if HR is enterBuffer bpm inside the zone
            if hr >= zoneLow + enterBuffer {
                if hr > zoneHigh + exitBuffer {
                    zoneState = .aboveZone
                } else {
                    zoneState = .inZone
                }
            }

        case .aboveZone:
            // Only re-enter if HR is enterBuffer bpm inside the zone
            if hr <= zoneHigh - enterBuffer {
                if hr < zoneLow - exitBuffer {
                    zoneState = .belowZone
                } else {
                    zoneState = .inZone
                }
            }
        }
    }

    // MARK: - Computed Stats

    var zonePercentage: Double {
        guard totalActiveSeconds > 0 else { return 0 }
        return Double(timeInZoneSeconds) / Double(totalActiveSeconds) * 100
    }

    var timeInZoneFormatted: String {
        let mins = timeInZoneSeconds / 60
        let secs = timeInZoneSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Position of current HR on the zone scale (0.0 = scale min, 1.0 = scale max)
    var hrScalePosition: Double {
        let scaleMin = Double(zoneLow - 20)
        let scaleMax = Double(zoneHigh + 20)
        let clamped = min(max(Double(currentHR), scaleMin), scaleMax)
        return (clamped - scaleMin) / (scaleMax - scaleMin)
    }

    /// Insight text based on zone percentage
    func completionInsight(zonePercent: Double) -> String {
        if zonePercent >= 80 {
            return "Excellent! You spent most of your walk in the optimal zone."
        } else if zonePercent >= 60 {
            return "Great session! \(Int(zonePercent))% in the fat-burning zone."
        } else if zonePercent >= 40 {
            return "Good effort. Try a slightly faster pace to stay in zone longer."
        } else {
            return "You spent \(Int(zonePercent))% in zone. Aim for a brisker pace next time."
        }
    }
}
