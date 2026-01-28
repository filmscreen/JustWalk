//
//  PedometerService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import CoreMotion
import Combine
import SwiftUI

/// Service for real-time step tracking using CMPedometer
@MainActor
final class PedometerService: ObservableObject {

    static let shared = PedometerService()

    private let pedometer = CMPedometer()

    @Published var isTracking = false
    @Published var currentSteps: Int = 0
    @Published var currentDistance: Double = 0 // meters
    @Published var currentPace: Double? = nil // seconds per meter
    @Published var currentCadence: Double? = nil // steps per second
    @Published var sessionStartTime: Date?
    @Published var error: Error?

    private var updateHandler: ((PedometerUpdate) -> Void)?

    private init() {}

    // MARK: - Availability

    /// Check if step counting is available
    static var isStepCountingAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    /// Check if distance tracking is available
    static var isDistanceAvailable: Bool {
        CMPedometer.isDistanceAvailable()
    }

    /// Check if pace tracking is available
    static var isPaceAvailable: Bool {
        CMPedometer.isPaceAvailable()
    }

    /// Check if cadence tracking is available
    static var isCadenceAvailable: Bool {
        CMPedometer.isCadenceAvailable()
    }

    /// Check authorization status
    static var authorizationStatus: CMAuthorizationStatus {
        CMPedometer.authorizationStatus()
    }

    // MARK: - Live Updates

    /// Start live pedometer updates from current time
    func startLiveUpdates(onUpdate: ((PedometerUpdate) -> Void)? = nil) {
        guard PedometerService.isStepCountingAvailable else {
            error = PedometerError.notAvailable
            return
        }

        guard PedometerService.authorizationStatus == .authorized ||
              PedometerService.authorizationStatus == .notDetermined else {
            error = PedometerError.notAuthorized
            return
        }

        let startDate = Date()
        sessionStartTime = startDate
        updateHandler = onUpdate
        isTracking = true
        currentSteps = 0
        currentDistance = 0
        currentPace = nil
        currentCadence = nil

        pedometer.startUpdates(from: startDate) { [weak self] data, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    self.error = error
                    self.isTracking = false
                    return
                }

                guard let data = data else { return }

                self.currentSteps = data.numberOfSteps.intValue

                if let distance = data.distance {
                    self.currentDistance = distance.doubleValue
                }

                if let pace = data.currentPace {
                    self.currentPace = pace.doubleValue
                }

                if let cadence = data.currentCadence {
                    self.currentCadence = cadence.doubleValue
                }

                let update = PedometerUpdate(
                    steps: self.currentSteps,
                    distance: self.currentDistance,
                    pace: self.currentPace,
                    cadence: self.currentCadence,
                    startDate: startDate,
                    endDate: data.endDate
                )

                self.updateHandler?(update)
            }
        }
    }

    /// Stop live pedometer updates
    func stopLiveUpdates() -> PedometerSessionSummary? {
        pedometer.stopUpdates()
        isTracking = false

        guard let startTime = sessionStartTime else { return nil }

        let summary = PedometerSessionSummary(
            startTime: startTime,
            endTime: Date(),
            totalSteps: currentSteps,
            totalDistance: currentDistance
        )

        // Reset state
        sessionStartTime = nil
        currentSteps = 0
        currentDistance = 0
        currentPace = nil
        currentCadence = nil
        updateHandler = nil

        return summary
    }

    // MARK: - Historical Queries

    /// Query pedometer data for a specific time range
    func queryPedometerData(from start: Date, to end: Date) async throws -> PedometerUpdate {
        guard PedometerService.isStepCountingAvailable else {
            throw PedometerError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data = data else {
                    continuation.resume(returning: PedometerUpdate(
                        steps: 0,
                        distance: 0,
                        pace: nil,
                        cadence: nil,
                        startDate: start,
                        endDate: end
                    ))
                    return
                }

                let update = PedometerUpdate(
                    steps: data.numberOfSteps.intValue,
                    distance: data.distance?.doubleValue ?? 0,
                    pace: data.currentPace?.doubleValue,
                    cadence: data.currentCadence?.doubleValue,
                    startDate: start,
                    endDate: end
                )

                continuation.resume(returning: update)
            }
        }
    }

    /// Get today's steps from pedometer
    func getTodaySteps() async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        let data = try await queryPedometerData(from: startOfDay, to: now)
        return data.steps
    }

    // MARK: - Pace Calculations

    /// Calculate pace category based on current pace
    func currentPaceCategory() -> PaceCategory {
        guard let pace = currentPace else { return .unknown }

        // pace is in seconds per meter
        let minutesPerKm = pace * 1000 / 60

        switch minutesPerKm {
        case ..<8:
            return .veryBrisk
        case 8..<10:
            return .brisk
        case 10..<13:
            return .moderate
        case 13..<16:
            return .slow
        default:
            return .verySlow
        }
    }

    /// Get formatted pace string
    func formattedPace() -> String {
        guard let pace = currentPace, pace > 0 else { return "--:--" }

        let minutesPerKm = pace * 1000 / 60
        let minutes = Int(minutesPerKm)
        let seconds = Int((minutesPerKm - Double(minutes)) * 60)

        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

// MARK: - Supporting Types

struct PedometerSessionSummary {
    let startTime: Date
    let endTime: Date
    let totalSteps: Int
    let totalDistance: Double

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var averagePace: Double? {
        guard totalDistance > 0 else { return nil }
        return duration / totalDistance
    }
}

enum PedometerError: LocalizedError {
    case notAvailable
    case notAuthorized
    case queryFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Step counting is not available on this device."
        case .notAuthorized:
            return "Motion & Fitness access has not been authorized."
        case .queryFailed:
            return "Failed to query pedometer data."
        }
    }
}
