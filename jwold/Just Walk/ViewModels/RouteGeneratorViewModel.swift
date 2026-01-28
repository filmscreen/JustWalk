//
//  RouteGeneratorViewModel.swift
//  Just Walk
//
//  Created by Claude on 2026-01-22.
//

import SwiftUI
import CoreLocation
import MapKit
import Combine

@MainActor
final class RouteGeneratorViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isGenerating = false
    @Published var generatedRoute: RouteGenerator.GeneratedRoute?
    @Published var selectedDistanceMiles: Double?
    @Published var selectedTimeMinutes: Int?
    @Published var error: String?

    // MARK: - Route Usage Tracking (Freemium)
    @AppStorage("lastRouteGenerationDate") private var lastGenerationDateString: String = ""
    @AppStorage("routesGeneratedToday") private var routesGeneratedToday: Int = 0

    // MARK: - Dependencies
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    // MARK: - Computed Properties

    var isPro: Bool {
        subscriptionManager.isPro
    }

    var canGenerateRoute: Bool {
        if isPro { return true }

        let today = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        if let lastDate = formatter.date(from: lastGenerationDateString),
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            return routesGeneratedToday < 1
        }
        return true // New day, reset
    }

    var routesRemainingToday: Int {
        if isPro { return Int.max }

        let today = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        if let lastDate = formatter.date(from: lastGenerationDateString),
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            return max(0, 1 - routesGeneratedToday)
        }
        return 1 // New day
    }

    var hasSelection: Bool {
        selectedDistanceMiles != nil || selectedTimeMinutes != nil
    }

    var targetDistanceMiles: Double? {
        if let distance = selectedDistanceMiles {
            return distance
        }
        if let minutes = selectedTimeMinutes {
            return timeToDistance(minutes: minutes)
        }
        return nil
    }

    // MARK: - Distance/Time Options

    let distanceOptions: [Double] = [1, 2, 3, 5]
    let timeOptions: [Int] = [15, 30, 45, 60]

    // MARK: - Selection Methods

    func selectDistance(_ miles: Double) {
        selectedDistanceMiles = miles
        selectedTimeMinutes = nil
        generatedRoute = nil
        error = nil
    }

    func selectTime(_ minutes: Int) {
        selectedTimeMinutes = minutes
        selectedDistanceMiles = nil
        generatedRoute = nil
        error = nil
    }

    func clearSelection() {
        selectedDistanceMiles = nil
        selectedTimeMinutes = nil
        generatedRoute = nil
        error = nil
    }

    // MARK: - Route Generation

    func generateRoute(from location: CLLocationCoordinate2D) {
        guard let targetMiles = targetDistanceMiles else {
            error = "Please select a distance or time"
            return
        }

        guard canGenerateRoute else {
            error = "You've used your free route for today. Upgrade to Pro for unlimited routes!"
            return
        }

        isGenerating = true
        error = nil

        RouteGenerator.shared.generateRoute(
            from: location,
            targetDistance: targetMiles
        ) { [weak self] result in
            Task { @MainActor in
                self?.isGenerating = false

                switch result {
                case .success(let route):
                    self?.generatedRoute = route
                    self?.recordRouteGeneration()
                case .failure(let routeError):
                    self?.error = routeError.localizedDescription
                }
            }
        }
    }

    func regenerateRoute(from location: CLLocationCoordinate2D) {
        generatedRoute = nil
        generateRoute(from: location)
    }

    // MARK: - Private Helpers

    private func recordRouteGeneration() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let today = formatter.string(from: Date())

        if lastGenerationDateString != today {
            routesGeneratedToday = 1
            lastGenerationDateString = today
        } else {
            routesGeneratedToday += 1
        }
    }

    /// Converts time in minutes to distance in miles using leisurely walking pace (2.5 mph)
    private func timeToDistance(minutes: Int) -> Double {
        let hours = Double(minutes) / 60.0
        return hours * 2.5  // 2.5 mph leisurely pace
    }
}
