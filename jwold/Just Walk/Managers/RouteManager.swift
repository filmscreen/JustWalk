//
//  RouteManager.swift
//  Just Walk
//
//  Central manager for Magic Route generation with regeneration limits.
//  Tracks re-roll counts per session and enforces free tier limits.
//

import Foundation
import Combine
import CoreLocation
import MapKit

/// Manages Magic Route generation with session-based regeneration limits
@MainActor
final class RouteManager: ObservableObject {

    // MARK: - Singleton

    static let shared = RouteManager()

    // MARK: - Published State

    /// The currently generated route
    @Published private(set) var currentRoute: RouteGenerator.GeneratedRoute?

    /// Number of times user has re-rolled this session
    @Published private(set) var regenerationCount: Int = 0

    /// Whether route generation is in progress
    @Published private(set) var isGenerating: Bool = false

    /// Error message for display
    @Published var errorMessage: String?

    // MARK: - Constants

    /// Free users can re-roll 2 times (3 total routes per session)
    static let freeUserRerollLimit = 2

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {}

    // MARK: - Computed Properties

    /// Check if user has Pro access
    var isPro: Bool {
        SubscriptionManager.shared.isPro || StoreManager.shared.isPro
    }

    /// Whether user can regenerate another route
    var canRegenerate: Bool {
        isPro || regenerationCount < Self.freeUserRerollLimit
    }

    /// Number of re-rolls remaining for free users
    var remainingRerolls: Int {
        if isPro { return Int.max }
        return max(0, Self.freeUserRerollLimit - regenerationCount)
    }

    /// User-friendly remaining re-rolls text
    var remainingRerollsText: String {
        if isPro { return "Unlimited" }
        let remaining = remainingRerolls
        if remaining == 0 { return "No re-rolls left" }
        return "\(remaining) re-roll\(remaining == 1 ? "" : "s") left"
    }

    // MARK: - Route Generation

    /// Generate a new route from the given location
    /// - Parameters:
    ///   - distance: Target distance in miles
    ///   - location: Starting location coordinate
    /// - Returns: The generated route, or nil if generation fails
    func generateRoute(distanceMiles: Double, from location: CLLocationCoordinate2D) async -> RouteGenerator.GeneratedRoute? {
        // Check regeneration limit (only applies after first generation)
        if currentRoute != nil && !canRegenerate {
            errorMessage = "Re-roll limit reached. Upgrade to Pro for unlimited re-rolls."
            return nil
        }

        isGenerating = true
        errorMessage = nil

        return await withCheckedContinuation { continuation in
            RouteGenerator.shared.generateRoute(from: location, targetDistance: distanceMiles) { [weak self] result in
                Task { @MainActor in
                    self?.isGenerating = false

                    switch result {
                    case .success(let route):
                        // Increment count only on regeneration (not first generation)
                        if self?.currentRoute != nil {
                            self?.regenerationCount += 1
                        }
                        self?.currentRoute = route
                        continuation.resume(returning: route)

                    case .failure(let error):
                        self?.errorMessage = error.localizedDescription
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    /// Generate route by time (converts to distance using walking pace)
    /// - Parameters:
    ///   - minutes: Target walking time in minutes
    ///   - location: Starting location coordinate
    /// - Returns: The generated route, or nil if generation fails
    func generateRoute(timeMinutes: Int, from location: CLLocationCoordinate2D) async -> RouteGenerator.GeneratedRoute? {
        let distanceMiles = timeToDistance(minutes: timeMinutes)
        return await generateRoute(distanceMiles: distanceMiles, from: location)
    }

    // MARK: - Session Management

    /// Reset session state when sheet is dismissed
    /// Clears the current route and resets regeneration count
    func resetSessionOnDismiss() {
        regenerationCount = 0
        currentRoute = nil
        errorMessage = nil
    }

    /// Reset session state when walk starts
    /// Keeps the current route but resets regeneration count
    func resetSessionOnWalkStart() {
        regenerationCount = 0
        errorMessage = nil
        // Keep currentRoute - it's needed for the active walk
    }

    /// Clear the current route without resetting regeneration count
    func clearCurrentRoute() {
        currentRoute = nil
        errorMessage = nil
    }

    // MARK: - Private Helpers

    /// Convert time in minutes to distance in miles using walking pace
    /// Uses 2.5 mph (leisurely walking pace)
    private func timeToDistance(minutes: Int) -> Double {
        let hours = Double(minutes) / 60.0
        return hours * 2.5  // 2.5 mph leisurely pace
    }
}
