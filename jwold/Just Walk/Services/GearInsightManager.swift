//
//  GearInsightManager.swift
//  Just Walk
//
//  Monitors user data for "friction points" and triggers gear recommendations.
//

import Foundation
import Combine

@MainActor
class GearInsightManager: ObservableObject {
    
    static let shared = GearInsightManager()
    
    // MARK: - Published Properties
    
    @Published var activeInsights: [GearInsight] = []
    @Published var lastEvaluationDate: Date?
    
    // MARK: - Dependencies

    private let storeManager = StoreManager.shared
    private let stepRepository = StepRepository.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    /// Threshold for Shoe Wall: 400 miles
    private let shoeWallThresholdMiles: Double = 400.0
    
    /// Threshold for Desk Trap: 40% below 7-day average
    private let deskTrapDropPercentage: Double = 0.40
    
    /// Number of consecutive low-step days to trigger Desk Trap
    private let deskTrapConsecutiveDays: Int = 3
    
    // MARK: - Persistence Keys
    
    private let shoeStartDistanceKey = "shoeStartDistanceMiles"
    private let lastInsightDateKey = "lastGearInsightDate"
    private let dismissedInsightsKey = "dismissedGearInsights"
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe Lifetime ownership (Focus Mode) to suppress insights
        storeManager.$ownsLifetime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ownsLifetime in
                if ownsLifetime {
                    self?.clearAllInsights()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    /// Evaluate user data for friction points
    func evaluateFrictionPoints() async {
        // Suppress if Focus Mode (Lifetime) is active
        guard !storeManager.ownsLifetime else {
            clearAllInsights()
            return
        }
        
        // Check Shoe Wall
        if let shoeInsight = await evaluateShoeWall() {
            addInsightIfNew(shoeInsight)
        }
        
        // Check Desk Trap
        if let deskInsight = await evaluateDeskTrap() {
            addInsightIfNew(deskInsight)
        }
        
        lastEvaluationDate = Date()
    }
    
    /// Dismiss an insight
    func dismissInsight(_ id: UUID) {
        if let index = activeInsights.firstIndex(where: { $0.id == id }) {
            activeInsights.remove(at: index)
            saveDismissedInsight(id)
        }
    }
    
    /// Clear all active insights
    func clearAllInsights() {
        activeInsights.removeAll()
    }
    
    /// Reset shoe distance tracking (user got new shoes)
    func resetShoeDistance() {
        let currentDistance = getCurrentTotalDistance()
        UserDefaults.standard.set(currentDistance, forKey: shoeStartDistanceKey)
    }
    
    // MARK: - Shoe Wall Detection
    
    private func evaluateShoeWall() async -> GearInsight? {
        let currentTotalDistance = getCurrentTotalDistance()
        let shoeStartDistance = UserDefaults.standard.double(forKey: shoeStartDistanceKey)
        
        let shoeMileage = currentTotalDistance - shoeStartDistance
        
        // Trigger at 400 miles
        guard shoeMileage >= shoeWallThresholdMiles else { return nil }
        
        // Check if already dismissed recently (within 30 days)
        if wasRecentlyDismissed(type: .shoeWall, withinDays: 30) { return nil }
        
        // Find a shoe recommendation
        let product = ProductDatabase.shared.getRecommendation(for: .shoeWall)
        
        return GearInsight(
            type: .shoeWall,
            headline: "Equipment Health Alert",
            explanation: "Your shoes have covered \(Int(shoeMileage)) miles. Running shoes typically need replacement at 300-500 miles to maintain proper support and injury prevention.",
            product: product
        )
    }
    
    // MARK: - Desk Trap Detection
    
    private func evaluateDeskTrap() async -> GearInsight? {
        // Get weekly step data using Pedometer++ merged algorithm
        let weeklySteps = await stepRepository.fetchHistoricalStepData(forPastDays: 10)
        
        guard weeklySteps.count >= 10 else { return nil }
        
        // Calculate 7-day average (days 4-10, excluding recent 3)
        let historicalDays = Array(weeklySteps.prefix(7))
        let recentDays = Array(weeklySteps.suffix(3))
        
        let historicalAverage = Double(historicalDays.reduce(0) { $0 + $1.steps }) / Double(historicalDays.count)
        
        guard historicalAverage > 0 else { return nil }
        
        // Check if last 3 days are all 40% below average
        let threshold = historicalAverage * (1.0 - deskTrapDropPercentage)
        let allBelowThreshold = recentDays.allSatisfy { Double($0.steps) < threshold }
        
        guard allBelowThreshold else { return nil }
        
        // Check if already dismissed recently
        if wasRecentlyDismissed(type: .deskTrap, withinDays: 14) { return nil }
        
        // Find a walking pad recommendation
        let product = ProductDatabase.shared.getRecommendation(for: .deskTrap)
        
        let dropPercent = Int((1.0 - (Double(recentDays.last?.steps ?? 0) / historicalAverage)) * 100)
        
        return GearInsight(
            type: .deskTrap,
            headline: "WFH Accessibility Alert",
            explanation: "Your step count has dropped \(dropPercent)% below your usual average for the past 3 days. A walking pad can help maintain your 10k goal while working from home.",
            product: product
        )
    }
    
    // MARK: - Helpers
    
    private func getCurrentTotalDistance() -> Double {
        // Get cumulative distance from HealthKit (in miles)
        // This would typically query HealthKit for walking+running distance
        // For now, estimate from step count: avg stride ~2.5 feet
        let totalSteps = stepRepository.todaySteps // Simplified - should be cumulative
        let strideLengthFeet = 2.5
        let feetPerMile = 5280.0
        return Double(totalSteps) * strideLengthFeet / feetPerMile
    }
    
    private func addInsightIfNew(_ insight: GearInsight) {
        // Check if we already have an insight of this type
        guard !activeInsights.contains(where: { $0.type == insight.type }) else { return }
        activeInsights.append(insight)
    }
    
    private func saveDismissedInsight(_ id: UUID) {
        var dismissed = getDismissedInsights()
        dismissed[id.uuidString] = Date()
        
        if let data = try? JSONEncoder().encode(dismissed) {
            UserDefaults.standard.set(data, forKey: dismissedInsightsKey)
        }
    }
    
    private func getDismissedInsights() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: dismissedInsightsKey),
              let dismissed = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return dismissed
    }
    
    private func wasRecentlyDismissed(type: InsightType, withinDays days: Int) -> Bool {
        // Check if any insight of this type was dismissed within the specified days
        let dismissed = getDismissedInsights()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return dismissed.values.contains { $0 > cutoffDate }
    }
}

// MARK: - Product Database

class ProductDatabase {
    static let shared = ProductDatabase()
    
    private var products: [RecommendedProduct] = []
    
    private init() {
        loadProducts()
    }
    
    private func loadProducts() {
        // Load from bundled JSON or hardcode for MVP
        products = [
            RecommendedProduct(
                id: "hoka-bondi-8",
                category: "running_shoes",
                brand: "Hoka",
                model: "Bondi 8",
                asin: "B0BXYZ123",
                impactId: nil,
                description: "Max-cushion daily trainer for all-day comfort",
                imageURL: nil
            ),
            RecommendedProduct(
                id: "brooks-ghost-15",
                category: "running_shoes",
                brand: "Brooks",
                model: "Ghost 15",
                asin: "B0CABC456",
                impactId: nil,
                description: "Smooth transitions and soft cushioning",
                imageURL: nil
            ),
            RecommendedProduct(
                id: "walkingpad-c2",
                category: "walking_pad",
                brand: "WalkingPad",
                model: "C2",
                asin: "B09XYZ789",
                impactId: nil,
                description: "Foldable under-desk treadmill for WFH",
                imageURL: nil
            )
        ]
    }
    
    func getRecommendation(for type: InsightType) -> RecommendedProduct? {
        switch type {
        case .shoeWall:
            return products.first { $0.category == "running_shoes" }
        case .deskTrap:
            return products.first { $0.category == "walking_pad" }
        }
    }
    
    func getAllProducts() -> [RecommendedProduct] {
        return products
    }
}
