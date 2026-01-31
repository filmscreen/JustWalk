//
//  FoodLog.swift
//  JustWalk
//
//  Data model for storing food/meal entries
//

import Foundation

// MARK: - MealType

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
    case unspecified

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .unspecified: return "Meal"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "🌮"
        case .dinner: return "🍽️"
        case .snack: return "🍫"
        case .unspecified: return "🍴"
        }
    }
}

// MARK: - EntrySource

enum EntrySource: String, Codable, CaseIterable {
    case ai           // Fully AI-generated from description
    case aiAdjusted   // AI-generated but user adjusted values
    case manual       // Manually entered by user
}

// MARK: - FoodLog

struct FoodLog: Identifiable, Codable, Equatable {
    let id: UUID
    let logID: String           // For CloudKit record name
    var date: Date              // The date this entry is for
    var mealType: MealType
    var name: String            // Short display name (e.g., "Chipotle bowl")
    var entryDescription: String // Full details for AI (e.g., "chicken, rice, beans, guac")
    var calories: Int
    var protein: Int            // grams
    var carbs: Int              // grams
    var fat: Int                // grams
    var source: EntrySource
    let createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        logID: String? = nil,
        date: Date = Date(),
        mealType: MealType = .unspecified,
        name: String,
        entryDescription: String = "",
        calories: Int = 0,
        protein: Int = 0,
        carbs: Int = 0,
        fat: Int = 0,
        source: EntrySource = .manual,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.logID = logID ?? id.uuidString
        self.date = date
        self.mealType = mealType
        self.name = name
        self.entryDescription = entryDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.source = source
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}
