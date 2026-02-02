//
//  CalorieGoalSettings.swift
//  JustWalk
//
//  Data model for calorie goal settings
//

import Foundation

// MARK: - Sex

enum BiologicalSex: String, Codable, CaseIterable {
    case male
    case female

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

// MARK: - Activity Level

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary
    case light
    case moderate
    case active

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Very Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Exercise 1-3 days/week"
        case .moderate: return "Exercise 3-5 days/week"
        case .active: return "Exercise 6-7 days/week"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        }
    }
}

// MARK: - CalorieGoalSettings

struct CalorieGoalSettings: Codable, Identifiable, Equatable {
    var id: UUID
    var settingsID: String          // For CloudKit record name
    var dailyGoal: Int              // The goal they set (e.g., 1650)
    var calculatedMaintenance: Int  // What we calculated (e.g., 2150)

    // Inputs for calculation
    var sex: BiologicalSex
    var age: Int                    // e.g., 32
    var heightCM: Double            // stored in CM internally
    var weightKG: Double            // stored in KG internally
    var activityLevel: ActivityLevel

    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        settingsID: String? = nil,
        dailyGoal: Int,
        calculatedMaintenance: Int,
        sex: BiologicalSex,
        age: Int,
        heightCM: Double,
        weightKG: Double,
        activityLevel: ActivityLevel,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.settingsID = settingsID ?? id.uuidString
        self.dailyGoal = dailyGoal
        self.calculatedMaintenance = calculatedMaintenance
        self.sex = sex
        self.age = age
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.activityLevel = activityLevel
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Unit Conversion Helpers

enum CalorieGoalHelpers {
    // Height conversions
    static func feetInchesToCM(feet: Int, inches: Int) -> Double {
        return Double(feet * 12 + inches) * 2.54
    }

    static func cmToFeetInches(cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches) / 12
        let inches = Int(totalInches.rounded()) % 12
        return (feet, inches)
    }

    // Weight conversions
    static func lbsToKG(lbs: Double) -> Double {
        return lbs * 0.453592
    }

    static func kgToLbs(kg: Double) -> Double {
        return kg / 0.453592
    }

    // MARK: - Maintenance Calculation (Mifflin-St Jeor)

    /// Calculates maintenance calories using Mifflin-St Jeor equation
    /// Returns result rounded to nearest 50
    static func calculateMaintenance(
        sex: BiologicalSex,
        age: Int,
        heightCM: Double,
        weightKG: Double,
        activityLevel: ActivityLevel
    ) -> Int {
        // BMR calculation
        let bmr: Double
        switch sex {
        case .male:
            bmr = (10.0 * weightKG) + (6.25 * heightCM) - (5.0 * Double(age)) + 5.0
        case .female:
            bmr = (10.0 * weightKG) + (6.25 * heightCM) - (5.0 * Double(age)) - 161.0
        }

        // Apply activity multiplier
        let maintenance = bmr * activityLevel.multiplier

        // Round to nearest 50
        return Int((maintenance / 50.0).rounded()) * 50
    }

    // MARK: - Weight Projection

    struct ProjectionMessage {
        let line1: String
        let line2: String
    }

    /// Returns projection message based on goal vs maintenance
    static func getProjectionMessage(goal: Int, maintenance: Int) -> ProjectionMessage {
        let difference = goal - maintenance
        let lbsPerMonth = abs(Double(difference) * 30.0 / 3500.0)

        if abs(difference) < 50 {
            return ProjectionMessage(
                line1: "At maintenance",
                line2: "Maintain your current weight"
            )
        }

        // Round to nearest 0.5
        let rounded = (lbsPerMonth * 2).rounded() / 2
        let lbsText = rounded == 1.0 ? "1 lb" : "\(formatted(rounded)) lbs"

        if difference < 0 {
            return ProjectionMessage(
                line1: "\(abs(difference)) below maintenance",
                line2: "→ Lose ~\(lbsText) per month"
            )
        } else {
            return ProjectionMessage(
                line1: "\(difference) above maintenance",
                line2: "→ Gain ~\(lbsText) per month"
            )
        }
    }

    private static func formatted(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
