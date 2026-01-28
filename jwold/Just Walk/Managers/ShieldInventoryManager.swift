//
//  ShieldInventoryManager.swift
//  Just Walk
//
//  Manages shield inventory with separate tracking for Pro monthly shields
//  and purchased shields. Consumes purchased shields first.
//

import Foundation
import Combine

@MainActor
final class ShieldInventoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ShieldInventoryManager()

    // MARK: - Dependencies

    private let streakService = StreakService.shared
    private let storeManager = StoreManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State

    @Published private(set) var proMonthlyShields: Int = 0
    @Published private(set) var purchasedShields: Int = 0
    @Published private(set) var proShieldsRefreshDate: Date?

    // MARK: - Computed Properties

    var totalShields: Int {
        proMonthlyShields + purchasedShields
    }

    var hasShields: Bool {
        totalShields > 0
    }

    /// Whether user is Pro and has used all monthly shields
    var isProWithNoMonthlyShields: Bool {
        storeManager.isPro && proMonthlyShields == 0
    }

    /// Formatted refresh date string (e.g., "Feb 1")
    var formattedRefreshDate: String? {
        guard let date = proShieldsRefreshDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Init

    private init() {
        // Sync initial state
        syncFromStreakData()

        // Observe StreakService changes
        streakService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncFromStreakData()
                }
            }
            .store(in: &cancellables)

        // Observe Pro status changes to grant shields
        // Combine hasActiveSubscription and ownsLifetime to detect Pro status
        Publishers.CombineLatest(storeManager.$hasActiveSubscription, storeManager.$ownsLifetime)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasSubscription, ownsLifetime in
                if hasSubscription || ownsLifetime {
                    self?.checkAndRefreshProShields()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Sync

    private func syncFromStreakData() {
        guard let streakData = streakService.getStreakData() else { return }

        // Migrate old shields if needed
        streakData.migrateShieldInventory()

        proMonthlyShields = streakData.proMonthlyShieldsRemaining
        purchasedShields = streakData.purchasedShieldsRemaining
        proShieldsRefreshDate = streakData.proShieldsRefreshDate
    }

    // MARK: - Public Methods

    /// Use one shield - consumes purchased first, then Pro monthly
    /// Returns true if successful
    func useShield() -> Bool {
        // Delegate to StreakService which handles persistence
        return streakService.useShield()
    }

    /// Add purchased shields (from one-time IAP)
    func addPurchasedShields(_ count: Int) {
        // Delegate to StreakService
        streakService.addPurchasedShields(count)
        syncFromStreakData()
    }

    /// Check and refresh Pro shields if new billing month
    func checkAndRefreshProShields() {
        guard storeManager.isPro else { return }

        streakService.checkAndGrantProMonthlyShields()
        syncFromStreakData()
    }

    // MARK: - Display Helpers

    /// Display string for shield count
    var shieldCountText: String {
        let count = totalShields
        return "\(count) shield\(count == 1 ? "" : "s") remaining"
    }

    /// Display string for Pro user who used all monthly shields
    var usedAllMonthlyText: String {
        "You've used all 3 shields this month"
    }

    /// Display string for refresh date
    var refreshDateText: String? {
        guard let date = formattedRefreshDate else { return nil }
        return "Shields refresh on \(date)"
    }
}
