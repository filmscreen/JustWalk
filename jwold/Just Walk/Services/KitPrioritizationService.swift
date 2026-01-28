//
//  KitPrioritizationService.swift
//  Just Walk
//
//  Smart prioritization logic for the Kit tab.
//

import Foundation
import Combine

@MainActor
class KitPrioritizationService: ObservableObject {
    
    static let shared = KitPrioritizationService()
    
    // MARK: - Published Properties
    
    @Published var pinnedProducts: [KitProduct] = []
    @Published var footwearProducts: [KitProduct] = []
    @Published var walkingPadsProducts: [KitProduct] = []
    @Published var recoveryProducts: [KitProduct] = []
    @Published var supplementsProducts: [KitProduct] = []
    @Published var intensityProducts: [KitProduct] = []
    
    // MARK: - Dependencies

    private let stepRepository = StepRepository.shared
    
    // MARK: - Thresholds
    
    private let shoeMileageThreshold: Double = 350.0
    private let streakThresholdForIntensity: Int = 5
    
    // MARK: - Initialization
    
    private init() {
        loadProducts()
    }
    
    // MARK: - Product Database

    private func loadProducts() {
        // WALK FROM HOME / WALKING PADS (Editor's Pick, Most Popular, Best Value)
        walkingPadsProducts = [
            KitProduct(
                id: "hifast-walking-pad",
                category: .walkingPads,
                brand: "HiFast",
                model: "Walking Pad",
                description: "Foldable under-desk treadmill",
                strategicBenefit: "People love the whisper-quiet motor that lets you walk while on calls.",
                imageName: "kit-hifast-walking-pad",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1AYwQJyMk5CBN6Cgf70llWTXhLn5cUjD"),
                amazonURL: URL(string: "https://amzn.to/3ZhlOes"),
                productBadge: .editorsPick
            ),
            KitProduct(
                id: "dearrun-walking-pad",
                category: .walkingPads,
                brand: "DearRun",
                model: "2025 Walking Pad",
                description: "Compact folding treadmill",
                strategicBenefit: "Outstanding value with features you'd expect at twice the price.",
                imageName: "kit-dearrun-walking-pad",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1A58j-JjVvW30gNyrMtzzTLh-WiOQ2-Kkq"),
                amazonURL: URL(string: "https://amzn.to/4pFv5I8"),
                productBadge: .mostPopular
            ),
            KitProduct(
                id: "treaflow-walking-pad",
                category: .walkingPads,
                brand: "TREAFLOW",
                model: "Walking Pad",
                description: "Ultra-slim desk treadmill",
                strategicBenefit: "Super affordable and folds flat for easy storage under your desk.",
                imageName: "kit-treaflow-walking-pad",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1g2v2MDCGgE-JY05Jt_6Tr_R0Aen4eNs"),
                amazonURL: URL(string: "https://amzn.to/4qTK5mF"),
                productBadge: .bestValue
            )
        ]

        // FOOTWEAR (Editor's Pick, Most Popular, Best Value)
        footwearProducts = [
            KitProduct(
                id: "asics-superblast-2",
                category: .footwear,
                brand: "ASICS",
                model: "SUPERBLAST 2",
                description: "Premium performance trainer",
                strategicBenefit: "Incredibly bouncy and light—feels like walking on springs.",
                imageName: "kit-asics-superblast-2",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1lQJcxm7JpwBWNNy6XXlPlqxPmb4hMppS"),
                amazonMensURL: URL(string: "https://amzn.to/4jKuXpw"),
                amazonWomensURL: URL(string: "https://amzn.to/4jKuXpw"),
                productBadge: .editorsPick
            ),
            KitProduct(
                id: "hoka-clifton-10",
                category: .footwear,
                brand: "HOKA",
                model: "Clifton 10",
                description: "Max-cushion daily trainer",
                strategicBenefit: "Cloud-like cushioning that people rave about for all-day comfort.",
                imageName: "kit-hoka-clifton-10",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1xpo5jsjNVLdvLPZz6WZePLUxVoNEsfNo"),
                amazonMensURL: URL(string: "https://amzn.to/3ZfuZMt"),
                amazonWomensURL: URL(string: "https://amzn.to/49nndpU"),
                productBadge: .mostPopular
            ),
            KitProduct(
                id: "nike-downshifter-12",
                category: .footwear,
                brand: "Nike",
                model: "Downshifter 12 PRM",
                description: "Everyday walking shoe",
                strategicBenefit: "Solid everyday shoe that delivers reliable comfort at a great price.",
                imageName: "kit-nike-downshifter-12",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1CKaLQT7C3dqBG9MEy4aQYxqSFl59EkM"),
                amazonMensURL: URL(string: "https://amzn.to/4jIBbGl"),
                amazonWomensURL: URL(string: "https://amzn.to/4jGn3NX"),
                productBadge: .bestValue
            )
        ]

        // RECOVERY & WELLNESS (Editor's Pick, Most Popular, Best Value)
        recoveryProducts = [
            KitProduct(
                id: "theragun-mini",
                category: .recovery,
                brand: "Therabody",
                model: "Theragun Mini",
                description: "Portable massage gun",
                strategicBenefit: "Fits in your bag and works great on sore muscles anywhere you go.",
                imageName: "kit-theragun-mini",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1W6O39Pb1UbJnXKTLwFi409z3AuF5LwFv"),
                amazonURL: URL(string: "https://amzn.to/4pLG6I2"),
                productBadge: .editorsPick
            ),
            KitProduct(
                id: "normatec-3-legs",
                category: .recovery,
                brand: "Hyperice",
                model: "Normatec 3 Legs",
                description: "Dynamic air compression boots",
                strategicBenefit: "Athletes swear by it for faster leg recovery after long walks.",
                imageName: "kit-normatec-3-legs",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1otaIQ18JxneWlhl3mpQaNWuHGVafKPDJ"),
                amazonURL: URL(string: "https://amzn.to/4pI3dDd"),
                productBadge: .mostPopular
            ),
            KitProduct(
                id: "lifepro-red-light-belt",
                category: .recovery,
                brand: "Lifepro",
                model: "Red Light Therapy Belt",
                description: "Wearable LED therapy device",
                strategicBenefit: "Easy to use and helps with soreness—just strap it on and relax.",
                imageName: "kit-lifepro-red-light-belt",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1VqXAHH6SP4G1VAPA0HBgjfCFZbSr3pHd"),
                amazonURL: URL(string: "https://amzn.to/4jIrk36"),
                productBadge: .bestValue
            )
        ]

        // SUPPLEMENTS (Editor's Pick, Most Popular)
        supplementsProducts = [
            KitProduct(
                id: "vital-proteins-collagen",
                category: .supplements,
                brand: "Vital Proteins",
                model: "Collagen Peptides",
                description: "Unflavored collagen powder",
                strategicBenefit: "Dissolves easily in coffee and people notice healthier skin and joints over time.",
                imageName: "vital-proteins-collagen",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1cBGJlqpwfkkqQQTW4ghVtPHHyTqUFAMY"),
                amazonURL: URL(string: "https://amzn.to/45JHXps"),
                productBadge: .editorsPick
            ),
            KitProduct(
                id: "lmnt-electrolyte",
                category: .supplements,
                brand: "LMNT",
                model: "Electrolyte Drink Mix",
                description: "Zero-sugar hydration packets",
                strategicBenefit: "Tastes great and helps you stay hydrated during long walks.",
                imageName: "kit-lmnt-electrolyte",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1rYInG0m-KDXBOWNPZFovYheUCTfXJQLK"),
                amazonURL: URL(string: "https://amzn.to/3Ng0R10"),
                productBadge: .mostPopular
            )
        ]

        // INTENSITY (Editor's Pick, Most Popular)
        intensityProducts = [
            KitProduct(
                id: "goruck-ruck-plate-carrier",
                category: .intensity,
                brand: "GORUCK",
                model: "Ruck Plate Carrier 3.0",
                description: "Weighted vest for rucking",
                strategicBenefit: "Built to last with a snug fit that stays put while you walk.",
                imageName: "kit-goruck-ruck-plate-carrier",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1pb4Dxhkoyy9jDmOGnaw7HNj0oi3PLa-R"),
                amazonURL: URL(string: "https://amzn.to/49GBSLS"),
                productBadge: .editorsPick
            ),
            KitProduct(
                id: "goruck-rucker-4",
                category: .intensity,
                brand: "GORUCK",
                model: "Rucker 4.0 20L",
                description: "Purpose-built rucking backpack",
                strategicBenefit: "Perfect for weighted walks with ergonomic straps and a comfy fit.",
                imageName: "kit-goruck-rucker-4",
                imageURL: URL(string: "https://drive.google.com/uc?export=view&id=1gkgCNKQqav64M6S2aiBbGGMi4jgmwlZD"),
                amazonURL: URL(string: "https://amzn.to/49oaymz"),
                productBadge: .mostPopular
            )
        ]
    }
    
    // MARK: - Smart Prioritization
    
    func evaluatePrioritization() async {
        pinnedProducts.removeAll()

        // Get user data using Pedometer++ merged algorithm
        let weeklySteps = await stepRepository.fetchHistoricalStepData(forPastDays: 7)
        let dailyGoal = UserDefaults(suiteName: "group.com.onworldtech.JustWalk")?.integer(forKey: "dailyStepGoal") ?? 10000
        
        // Calculate 7-day average
        let totalSteps = weeklySteps.reduce(0) { $0 + $1.steps }
        let avgSteps = weeklySteps.isEmpty ? 0 : totalSteps / weeklySteps.count
        
        // Get shoe mileage (from UserDefaults or estimate)
        let shoeMileage = getCurrentShoeMileage()
        
        // LOGIC 1: Low Steps → Pin Walking Pads
        if avgSteps < dailyGoal && avgSteps > 0 {
            if var walkingPad = walkingPadsProducts.first {
                walkingPad.isPinned = true
                walkingPad.badgeText = "Boost Your Average"
                pinnedProducts.append(walkingPad)
            }
        }
        
        // LOGIC 2: High Shoe Mileage → Pin Shoes
        if shoeMileage > shoeMileageThreshold {
            if var shoes = footwearProducts.first {
                shoes.isPinned = true
                shoes.badgeText = "Time for a Refresh"
                pinnedProducts.append(shoes)
            }
        }
        
        // Note: Intensity products (weighted vest) are always shown in the Intensity section below,
        // so we don't pin them to "Recommended For You" to avoid duplication.
    }
    
    // MARK: - Helpers
    
    private func calculateStreak(from steps: [DayStepData], goal: Int) -> Int {
        var streak = 0
        for day in steps.reversed() {
            if day.steps >= goal {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
    
    private func getCurrentShoeMileage() -> Double {
        // Get cumulative distance since shoe start date
        let shoeStartMiles = UserDefaults.standard.double(forKey: "shoeStartDistanceMiles")
        let currentMiles = estimateCurrentMileage()
        return currentMiles - shoeStartMiles
    }
    
    private func estimateCurrentMileage() -> Double {
        // Rough estimate: 2000 steps = 1 mile
        let totalSteps = stepRepository.todaySteps
        return Double(totalSteps) / 2000.0
    }
}
