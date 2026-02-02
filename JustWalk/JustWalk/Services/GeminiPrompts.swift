//
//  GeminiPrompts.swift
//  JustWalk
//
//  Prompt templates for Gemini AI food estimation
//

import Foundation
import os.log

private let parserLogger = Logger(subsystem: "onworldtech.JustWalk", category: "FoodEstimateParser")

// MARK: - Validation Ranges

enum FoodEstimateValidation {
    /// Valid calorie range (0 to 5,000 - reasonable max for a single food item)
    static let calorieRange = 0...5000

    /// Valid macro range in grams (0 to 500 - reasonable max for a single food item)
    static let macroRange = 0...500

    /// Maximum name length
    static let maxNameLength = 100

    /// Default values for missing/invalid fields
    static let defaultName = "Food Entry"
    static let defaultCalories = 200
    static let defaultProtein = 10
    static let defaultCarbs = 25
    static let defaultFat = 8

    /// Tolerance for macro-calorie validation (30%)
    static let macroCalorieTolerance = 0.30

    /// Validate that macros roughly add up to calories
    /// Formula: (protein × 4) + (carbs × 4) + (fat × 9) ≈ calories (within tolerance)
    /// - Parameters:
    ///   - calories: Total calories
    ///   - protein: Protein in grams
    ///   - carbs: Carbs in grams
    ///   - fat: Fat in grams
    /// - Returns: True if macros are consistent with calories
    static func validateMacroCalorieConsistency(
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int
    ) -> Bool {
        // Skip validation for very low calorie items (rounding errors would cause false negatives)
        guard calories >= 50 else { return true }

        let calculatedCalories = (protein * 4) + (carbs * 4) + (fat * 9)
        let difference = abs(calculatedCalories - calories)
        let tolerance = Double(calories) * macroCalorieTolerance

        return Double(difference) <= tolerance
    }

    /// Validate a food estimate for sanity checks
    /// - Parameter estimate: The estimate to validate
    /// - Returns: True if the estimate passes all validation checks
    static func validate(_ estimate: FoodEstimate) -> Bool {
        // Check calorie range
        guard calorieRange.contains(estimate.calories) else {
            parserLogger.warning("Calories \(estimate.calories) out of range")
            return false
        }

        // Check macro ranges
        guard macroRange.contains(estimate.protein) else {
            parserLogger.warning("Protein \(estimate.protein) out of range")
            return false
        }

        guard macroRange.contains(estimate.carbs) else {
            parserLogger.warning("Carbs \(estimate.carbs) out of range")
            return false
        }

        guard macroRange.contains(estimate.fat) else {
            parserLogger.warning("Fat \(estimate.fat) out of range")
            return false
        }

        // Check macro-calorie consistency
        if !validateMacroCalorieConsistency(
            calories: estimate.calories,
            protein: estimate.protein,
            carbs: estimate.carbs,
            fat: estimate.fat
        ) {
            parserLogger.warning("Macro-calorie mismatch for \(estimate.name): \(estimate.calories) cal vs calculated \((estimate.protein * 4) + (estimate.carbs * 4) + (estimate.fat * 9))")
            // Don't fail validation, just log warning - AI estimates can have reasonable variance
        }

        return true
    }
}

// MARK: - Parsing Error

enum FoodEstimateParseError: LocalizedError {
    case emptyResponse
    case invalidJSON(String)
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "Empty response from AI"
        case .invalidJSON(let details):
            return "Invalid JSON: \(details)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        }
    }
}

// MARK: - Food Estimation Response Model

struct FoodEstimate: Codable, Equatable {
    let name: String
    let description: String  // Original user input
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let confidence: ConfidenceLevel
    let notes: String?

    enum ConfidenceLevel: String, Codable, CaseIterable {
        case low
        case medium
        case high

        var displayText: String {
            switch self {
            case .low: return "Low confidence"
            case .medium: return "Medium confidence"
            case .high: return "High confidence"
            }
        }

        /// Initialize from string, defaulting to low if unknown
        init(from string: String) {
            self = ConfidenceLevel(rawValue: string.lowercased()) ?? .low
        }
    }

    // MARK: - Custom Decoding with Defaults

    enum CodingKeys: String, CodingKey {
        case name, description, calories, protein, carbs, fat, confidence, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Name: required, but provide default if missing
        let rawName = try container.decodeIfPresent(String.self, forKey: .name)
        self.name = FoodEstimate.validateName(rawName)

        // Description: not from JSON - will be set via withDescription()
        self.description = ""

        // Calories: validate range
        let rawCalories = try container.decodeIfPresent(Int.self, forKey: .calories)
        self.calories = FoodEstimate.validateCalories(rawCalories)

        // Macros: validate ranges
        let rawProtein = try container.decodeIfPresent(Int.self, forKey: .protein)
        self.protein = FoodEstimate.validateMacro(rawProtein, default: FoodEstimateValidation.defaultProtein)

        let rawCarbs = try container.decodeIfPresent(Int.self, forKey: .carbs)
        self.carbs = FoodEstimate.validateMacro(rawCarbs, default: FoodEstimateValidation.defaultCarbs)

        let rawFat = try container.decodeIfPresent(Int.self, forKey: .fat)
        self.fat = FoodEstimate.validateMacro(rawFat, default: FoodEstimateValidation.defaultFat)

        // Confidence: default to low if missing or invalid
        if let rawConfidence = try container.decodeIfPresent(String.self, forKey: .confidence) {
            self.confidence = ConfidenceLevel(from: rawConfidence)
        } else {
            self.confidence = .low
        }

        // Notes: optional
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    // MARK: - Direct Initializer

    init(
        name: String,
        description: String = "",
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        confidence: ConfidenceLevel = .medium,
        notes: String? = nil
    ) {
        self.name = FoodEstimate.validateName(name)
        self.description = description
        self.calories = FoodEstimate.validateCalories(calories)
        self.protein = FoodEstimate.validateMacro(protein, default: FoodEstimateValidation.defaultProtein)
        self.carbs = FoodEstimate.validateMacro(carbs, default: FoodEstimateValidation.defaultCarbs)
        self.fat = FoodEstimate.validateMacro(fat, default: FoodEstimateValidation.defaultFat)
        self.confidence = confidence
        self.notes = notes
    }

    /// Create a copy with the description set
    func withDescription(_ description: String) -> FoodEstimate {
        FoodEstimate(
            name: name,
            description: description,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: confidence,
            notes: notes
        )
    }

    // MARK: - Validation Helpers

    private static func validateName(_ name: String?) -> String {
        guard let name = name, !name.isEmpty else {
            return FoodEstimateValidation.defaultName
        }
        if name.count > FoodEstimateValidation.maxNameLength {
            return String(name.prefix(FoodEstimateValidation.maxNameLength))
        }
        return name
    }

    private static func validateCalories(_ calories: Int?) -> Int {
        guard let calories = calories else {
            return FoodEstimateValidation.defaultCalories
        }
        return FoodEstimateValidation.calorieRange.clamped(calories)
    }

    private static func validateMacro(_ value: Int?, default defaultValue: Int) -> Int {
        guard let value = value else {
            return defaultValue
        }
        return FoodEstimateValidation.macroRange.clamped(value)
    }

    // MARK: - Convert to FoodLog

    /// Convert this estimate to a FoodLog entry
    func toFoodLog(
        date: Date = Date(),
        mealType: MealType = .unspecified
    ) -> FoodLog {
        FoodLog(
            date: date,
            mealType: mealType,
            name: name,
            entryDescription: description,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            source: .ai
        )
    }

    // MARK: - Debug Description

    var debugDescription: String {
        """
        FoodEstimate:
          name: \(name)
          description: \(description)
          calories: \(calories)
          protein: \(protein)g
          carbs: \(carbs)g
          fat: \(fat)g
          confidence: \(confidence.rawValue)
          notes: \(notes ?? "none")
        """
    }
}

// MARK: - Range Clamping Extension

private extension ClosedRange where Bound == Int {
    func clamped(_ value: Int) -> Int {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

// MARK: - Food Estimate Parser

enum FoodEstimateParser {

    /// Parse a JSON response from Gemini into a FoodEstimate
    /// Handles malformed JSON, missing fields, and out-of-range values
    /// - Parameters:
    ///   - jsonString: The raw JSON string from Gemini
    ///   - originalDescription: The original food description from the user
    /// - Returns: A validated FoodEstimate with the description attached
    static func parse(_ jsonString: String, originalDescription: String = "") throws -> FoodEstimate {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            parserLogger.error("Empty response received")
            throw FoodEstimateParseError.emptyResponse
        }

        // Try to extract JSON if wrapped in markdown code blocks
        let cleanedJSON = extractJSON(from: trimmed)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            parserLogger.error("Failed to convert string to data")
            throw FoodEstimateParseError.invalidJSON("Could not encode as UTF-8")
        }

        // First try standard decoding
        do {
            let estimate = try JSONDecoder().decode(FoodEstimate.self, from: jsonData)
            parserLogger.info("Successfully parsed food estimate: \(estimate.name)")
            return estimate.withDescription(originalDescription)
        } catch let decodingError {
            parserLogger.warning("Standard decoding failed, trying manual parsing: \(decodingError.localizedDescription)")

            // Try manual parsing for malformed JSON
            return try parseManually(cleanedJSON, originalDescription: originalDescription)
        }
    }

    /// Extract JSON from potential markdown code blocks
    private static func extractJSON(from text: String) -> String {
        var result = text

        // Remove markdown code block markers
        if result.hasPrefix("```json") {
            result = String(result.dropFirst(7))
        } else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }

        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Manual parsing for malformed JSON
    private static func parseManually(_ jsonString: String, originalDescription: String) throws -> FoodEstimate {
        // Try to parse as dictionary
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            parserLogger.error("Failed to parse as dictionary")
            throw FoodEstimateParseError.invalidJSON("Not a valid JSON object")
        }

        // Extract values with type coercion
        let name = extractString(from: dict, key: "name") ?? FoodEstimateValidation.defaultName
        let calories = extractInt(from: dict, key: "calories") ?? FoodEstimateValidation.defaultCalories
        let protein = extractInt(from: dict, key: "protein") ?? FoodEstimateValidation.defaultProtein
        let carbs = extractInt(from: dict, key: "carbs") ?? FoodEstimateValidation.defaultCarbs
        let fat = extractInt(from: dict, key: "fat") ?? FoodEstimateValidation.defaultFat
        let confidenceStr = extractString(from: dict, key: "confidence") ?? "low"
        let notes = extractString(from: dict, key: "notes")

        let estimate = FoodEstimate(
            name: name,
            description: originalDescription,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            confidence: FoodEstimate.ConfidenceLevel(from: confidenceStr),
            notes: notes
        )

        parserLogger.info("Manually parsed food estimate: \(estimate.name)")
        return estimate
    }

    /// Extract string value, handling various types
    private static func extractString(from dict: [String: Any], key: String) -> String? {
        if let str = dict[key] as? String, !str.isEmpty, str != "null" {
            return str
        }
        return nil
    }

    /// Extract integer value, handling strings and doubles
    private static func extractInt(from dict: [String: Any], key: String) -> Int? {
        if let intVal = dict[key] as? Int {
            return intVal
        }
        if let doubleVal = dict[key] as? Double {
            return Int(doubleVal)
        }
        if let strVal = dict[key] as? String, let intVal = Int(strVal) {
            return intVal
        }
        return nil
    }

    /// Create a default estimate when parsing fails completely
    static func createDefault(for description: String) -> FoodEstimate {
        parserLogger.warning("Creating default estimate for: \(description)")

        // Create a simple name from the description
        let words = description.split(separator: " ").prefix(3)
        let name = words.isEmpty ? FoodEstimateValidation.defaultName : words.joined(separator: " ").capitalized

        return FoodEstimate(
            name: name,
            description: description,
            calories: FoodEstimateValidation.defaultCalories,
            protein: FoodEstimateValidation.defaultProtein,
            carbs: FoodEstimateValidation.defaultCarbs,
            fat: FoodEstimateValidation.defaultFat,
            confidence: .low,
            notes: "Could not estimate - using defaults"
        )
    }

    // MARK: - Parse Itemized Array Response

    /// Parse a JSON response containing multiple food items
    /// - Parameters:
    ///   - jsonString: The raw JSON string from Gemini
    ///   - originalDescription: The original food description from the user
    /// - Returns: An array of validated FoodEstimates
    static func parseItemized(_ jsonString: String, originalDescription: String = "") throws -> [FoodEstimate] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            parserLogger.error("Empty response received for itemized parsing")
            throw FoodEstimateParseError.emptyResponse
        }

        // Try to extract JSON if wrapped in markdown code blocks
        let cleanedJSON = extractJSON(from: trimmed)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            parserLogger.error("Failed to convert string to data")
            throw FoodEstimateParseError.invalidJSON("Could not encode as UTF-8")
        }

        // Try to parse as dictionary with items array
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let items = dict["items"] as? [[String: Any]] else {
            parserLogger.warning("Failed to parse as items array, trying single item fallback")
            // Fallback: try parsing as single item
            let singleEstimate = try parse(jsonString, originalDescription: originalDescription)
            return [singleEstimate]
        }

        // Parse each item
        var estimates: [FoodEstimate] = []
        for itemDict in items {
            let name = extractString(from: itemDict, key: "name") ?? FoodEstimateValidation.defaultName
            // Use item-specific description from AI, fallback to original if not provided
            let itemDescription = extractString(from: itemDict, key: "description") ?? name
            let calories = extractInt(from: itemDict, key: "calories") ?? FoodEstimateValidation.defaultCalories
            let protein = extractInt(from: itemDict, key: "protein") ?? FoodEstimateValidation.defaultProtein
            let carbs = extractInt(from: itemDict, key: "carbs") ?? FoodEstimateValidation.defaultCarbs
            let fat = extractInt(from: itemDict, key: "fat") ?? FoodEstimateValidation.defaultFat
            let confidenceStr = extractString(from: itemDict, key: "confidence") ?? "medium"
            let notes = extractString(from: itemDict, key: "notes")

            let estimate = FoodEstimate(
                name: name,
                description: itemDescription,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                confidence: FoodEstimate.ConfidenceLevel(from: confidenceStr),
                notes: notes
            )

            // Validate the estimate (logs warnings but doesn't reject)
            _ = FoodEstimateValidation.validate(estimate)

            estimates.append(estimate)
        }

        if estimates.isEmpty {
            parserLogger.warning("No items parsed, creating default")
            return [createDefault(for: originalDescription)]
        }

        parserLogger.info("Successfully parsed \(estimates.count) food items")
        return estimates
    }
}

// MARK: - Single Food Estimation Result (for backward compatibility)

/// Result for single-item food estimation (used by RecalculateComparisonView and legacy methods)
enum SingleFoodEstimationResult {
    /// Successful estimation from AI
    case success(FoodEstimate)

    /// Error occurred but user can retry
    case retryable(error: GeminiError)

    /// Error occurred - user should enter manually
    case needsManualEntry(error: GeminiError)

    /// The estimate to use (available in success case)
    var estimate: FoodEstimate? {
        switch self {
        case .success(let estimate):
            return estimate
        case .retryable, .needsManualEntry:
            return nil
        }
    }

    /// User-friendly message describing the result
    var userMessage: String? {
        switch self {
        case .success:
            return nil
        case .retryable(let error):
            return error.userMessage
        case .needsManualEntry(let error):
            return error.userMessage
        }
    }

    /// Whether the result has a usable estimate
    var hasEstimate: Bool {
        estimate != nil
    }
}

// MARK: - Food Estimation Result (Itemized)

/// Result of attempting to estimate food nutrition via AI
/// Now returns an array of itemized food estimates
enum FoodEstimationResult {
    /// Successful estimation from AI - array of itemized food items
    case success([FoodEstimate])

    /// Error occurred but user can retry
    case retryable(error: GeminiError)

    /// Error occurred - user should enter manually
    case needsManualEntry(error: GeminiError)

    /// The estimates to use (available in success case)
    var estimates: [FoodEstimate]? {
        switch self {
        case .success(let estimates):
            return estimates
        case .retryable, .needsManualEntry:
            return nil
        }
    }

    /// User-friendly message describing the result
    var userMessage: String? {
        switch self {
        case .success:
            return nil  // No message needed for clean success
        case .retryable(let error):
            return error.userMessage
        case .needsManualEntry(let error):
            return error.userMessage
        }
    }

    /// Whether the result has usable estimates
    var hasEstimates: Bool {
        estimates != nil && !(estimates?.isEmpty ?? true)
    }

    /// Whether the user should be prompted to enter manually
    var shouldShowManualEntry: Bool {
        switch self {
        case .success:
            return false
        case .retryable(let error):
            return error.shouldOfferManualEntry
        case .needsManualEntry:
            return true
        }
    }

    /// Whether a retry button should be shown
    var shouldShowRetry: Bool {
        switch self {
        case .retryable:
            return true
        default:
            return false
        }
    }
}

// MARK: - Food Estimation State

/// Observable state manager for food estimation UI
/// Handles loading state, cancellation, and result tracking
/// Now supports multiple itemized food estimates
@MainActor
@Observable
final class FoodEstimationState {

    // MARK: - State

    /// Current phase of the estimation
    enum Phase: Equatable {
        case idle
        case loading(message: String)
        case success([FoodEstimate])  // Now returns array of itemized estimates
        case error(message: String, canRetry: Bool, canEnterManually: Bool)
    }

    /// Current phase
    private(set) var phase: Phase = .idle

    /// The current task (for cancellation)
    private var currentTask: Task<Void, Never>?

    /// The food description being estimated
    private(set) var foodDescription: String = ""

    // MARK: - Computed Properties

    /// Whether an estimation is in progress
    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    /// Loading message to display
    var loadingMessage: String? {
        if case .loading(let message) = phase { return message }
        return nil
    }

    /// The successful estimates array, if available
    var estimates: [FoodEstimate]? {
        if case .success(let estimates) = phase { return estimates }
        return nil
    }

    /// Error message, if in error state
    var errorMessage: String? {
        if case .error(let message, _, _) = phase { return message }
        return nil
    }

    /// Whether retry is available
    var canRetry: Bool {
        if case .error(_, let canRetry, _) = phase { return canRetry }
        return false
    }

    /// Whether manual entry should be offered
    var canEnterManually: Bool {
        if case .error(_, _, let canEnterManually) = phase { return canEnterManually }
        return false
    }

    // MARK: - Actions

    /// Start estimating food from a description
    /// - Parameter description: What the user ate
    func estimate(_ description: String) {
        // Cancel any existing request
        cancel()

        foodDescription = description
        phase = .loading(message: "Estimating...")

        currentTask = Task {
            // Add slight delay for UI feedback
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Check for cancellation
            guard !Task.isCancelled else {
                phase = .idle
                return
            }

            // Update message for longer requests
            let messageTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                if !Task.isCancelled && isLoading {
                    phase = .loading(message: "Still working...")
                }
            }

            // Perform the itemized estimation
            let result = await GeminiService.shared.estimateFoodItemized(description)

            // Cancel the message update task
            messageTask.cancel()

            // Check for cancellation again
            guard !Task.isCancelled else {
                phase = .idle
                return
            }

            // Handle the result
            switch result {
            case .success(let estimates):
                phase = .success(estimates)

            case .retryable(let error):
                phase = .error(
                    message: error.userMessage,
                    canRetry: true,
                    canEnterManually: error.shouldOfferManualEntry
                )

            case .needsManualEntry(let error):
                phase = .error(
                    message: error.userMessage,
                    canRetry: false,
                    canEnterManually: true
                )
            }
        }
    }

    /// Cancel the current estimation
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        if isLoading {
            phase = .idle
        }
    }

    /// Retry the last estimation
    func retry() {
        guard !foodDescription.isEmpty else { return }
        estimate(foodDescription)
    }

    /// Reset to idle state
    func reset() {
        cancel()
        foodDescription = ""
        phase = .idle
    }

    /// Set the result directly (for manual entry or editing)
    func setEstimates(_ estimates: [FoodEstimate]) {
        cancel()
        if let first = estimates.first {
            foodDescription = first.description
        }
        phase = .success(estimates)
    }
}

// MARK: - Gemini Prompts

enum GeminiPrompts {

    // MARK: - Itemized Food Estimation Prompt

    /// Builds a prompt for estimating calories and macronutrients from a food description.
    /// Returns an array of individual food items for separate tracking.
    /// - Parameter foodDescription: The user's description of what they ate
    /// - Returns: The formatted prompt string for Gemini
    static func foodEstimation(for foodDescription: String) -> String {
        """
        You are a nutritionist assistant. Your job is to estimate calories and macronutrients for foods described by users.

        FOOD DESCRIPTION:
        "\(foodDescription)"

        RULES:

        1. ACCURACY FIRST
           - Base estimates on USDA food database values, restaurant nutrition data, or established nutritional references
           - Do not guess — if you're uncertain, use conservative estimates (slightly higher calories)
           - For branded items (Starbucks, McDonald's, etc.), use their published nutrition data

        2. STATE YOUR ASSUMPTIONS
           - Always specify the portion size you're assuming in the description field
           - Always specify preparation method if it affects nutrition
           - If the description is ambiguous, pick the most common interpretation and state it

        3. PORTION SIZES
           - Use standard serving sizes when not specified:
             - Sandwich: 1 whole sandwich on standard bread
             - Latte/Coffee: 16oz (Grande) unless specified
             - Rice/Pasta: 1 cup cooked
             - Meat/Protein: 4oz cooked weight
             - Fruit: 1 medium piece
             - Salad: 2 cups greens with stated toppings
           - If user specifies "small", "medium", "large", adjust accordingly:
             - Small: ~75% of standard
             - Large: ~150% of standard

        4. RESPONSE FORMAT
           Return valid JSON only. No markdown, no explanation, no extra text.

           {
             "items": [
               {
                 "name": "Short display name (2-4 words)",
                 "description": "What you assumed (portion, ingredients, preparation)",
                 "calories": number,
                 "protein": number,
                 "carbs": number,
                 "fat": number,
                 "confidence": "low" | "medium" | "high",
                 "notes": "Optional: important variations or assumptions"
               }
             ]
           }

        5. MULTIPLE ITEMS
           - If the user describes multiple foods, return each as a separate item
           - "2 eggs and toast" = two separate items in the array
           - "a burger and fries" = two separate items in the array

        6. NUMBER FORMATTING
           - All numbers must be integers (no decimals)
           - Round to nearest whole number
           - Calories should be rounded to nearest 5 for cleaner display

        7. HANDLE UNCERTAINTY
           - If you cannot reasonably estimate (e.g., "my grandma's recipe"), set confidence to "low" and provide your best guess
           - If a food doesn't exist or is nonsensical, return a reasonable interpretation

        8. COMMON FOODS REFERENCE (use these as baselines for accuracy)
           - Large egg: 70 cal, 6g protein, 0g carbs, 5g fat
           - Slice of bread: 80 cal, 3g protein, 15g carbs, 1g fat
           - Chicken breast (4oz): 185 cal, 35g protein, 0g carbs, 4g fat
           - White rice (1 cup): 205 cal, 4g protein, 45g carbs, 0g fat
           - Banana (medium): 105 cal, 1g protein, 27g carbs, 0g fat
           - Olive oil (1 tbsp): 120 cal, 0g protein, 0g carbs, 14g fat

        EXAMPLES:

        Input: "a turkey and avocado sandwich"
        Output: {"items":[{"name":"Turkey Avocado Sandwich","description":"4oz turkey breast, 1/4 avocado, lettuce, tomato, mayo on whole wheat bread","calories":480,"protein":32,"carbs":38,"fat":22,"confidence":"medium","notes":"Without cheese. Add ~100 cal if cheese included."}]}

        Input: "a small vanilla latte"
        Output: {"items":[{"name":"Vanilla Latte (Small)","description":"12oz latte with 2% milk and vanilla syrup","calories":190,"protein":9,"carbs":27,"fat":5,"confidence":"high","notes":"Starbucks Tall equivalent. Oat milk adds ~30 cal."}]}

        Input: "a beef gyro"
        Output: {"items":[{"name":"Beef Gyro","description":"4oz beef/lamb gyro meat in pita with tzatziki, tomato, onion","calories":550,"protein":28,"carbs":45,"fat":28,"confidence":"medium","notes":"Traditional US-style. Without fries."}]}

        Input: "2 scrambled eggs and a piece of toast with butter"
        Output: {"items":[{"name":"Scrambled Eggs","description":"2 large eggs scrambled with butter","calories":180,"protein":12,"carbs":1,"fat":14,"confidence":"high","notes":null},{"name":"Toast with Butter","description":"1 slice bread with 1 tbsp butter","calories":180,"protein":3,"carbs":15,"fat":12,"confidence":"high","notes":null}]}

        Input: "a big mac"
        Output: {"items":[{"name":"Big Mac","description":"McDonald's Big Mac sandwich","calories":550,"protein":25,"carbs":45,"fat":30,"confidence":"high","notes":"Based on McDonald's published nutrition data."}]}

        Input: "chicken salad"
        Output: {"items":[{"name":"Chicken Salad","description":"2 cups mixed greens, 4oz grilled chicken breast, light dressing","calories":350,"protein":35,"carbs":12,"fat":18,"confidence":"medium","notes":"Assumes light vinaigrette. Creamy dressing adds ~100 cal."}]}

        Input: "a slice of pepperoni pizza"
        Output: {"items":[{"name":"Pepperoni Pizza Slice","description":"1 large slice (1/8 of 14-inch pizza) pepperoni pizza","calories":310,"protein":13,"carbs":35,"fat":14,"confidence":"medium","notes":"Chain restaurant style. Thin crust is ~50 cal less."}]}

        Now estimate each item in the food description above.
        """
    }

    // MARK: - Recalculation Prompt

    /// Builds a prompt for recalculating nutrition when a user modifies a food entry.
    /// Provides context about the original estimate to ensure consistent adjustments.
    /// - Parameters:
    ///   - newDescription: The updated food description from the user
    ///   - originalCalories: The original calorie estimate
    ///   - originalProtein: The original protein estimate (grams)
    ///   - originalCarbs: The original carbs estimate (grams)
    ///   - originalFat: The original fat estimate (grams)
    /// - Returns: The formatted prompt string for Gemini
    static func foodRecalculation(
        newDescription: String,
        originalCalories: Int,
        originalProtein: Int,
        originalCarbs: Int,
        originalFat: Int
    ) -> String {
        """
        You are a nutritionist assistant. The user has MODIFIED their food entry and needs an updated estimate.

        UPDATED FOOD DESCRIPTION:
        "\(newDescription)"

        PREVIOUS ESTIMATE (for reference):
        - Calories: \(originalCalories)
        - Protein: \(originalProtein)g
        - Carbs: \(originalCarbs)g
        - Fat: \(originalFat)g

        INSTRUCTIONS:
        1. Estimate the nutrition for the UPDATED description accurately
        2. The user may have ADDED ingredients, REMOVED ingredients, or CHANGED portions
        3. If ingredients were ADDED (e.g., "with bacon"), the new estimate should be HIGHER than the original
        4. If ingredients were REMOVED, the new estimate should be LOWER
        5. If portions changed, adjust accordingly
        6. Do NOT simply copy the original values - calculate based on the new description
        7. Use realistic nutritional values for common foods
        8. Round all numbers to reasonable integers

        IMPORTANT: If the new description includes MORE food items than before, the calories MUST increase. If it includes FEWER items, calories should decrease.

        Respond with ONLY valid JSON, no markdown, no explanation:
        {"name": "Short Name", "calories": 0, "protein": 0, "carbs": 0, "fat": 0, "confidence": "medium"}

        EXAMPLES:

        Previous: 650 cal for "fried rice"
        Updated: "fried rice with 2 strips of bacon"
        Result: {"name":"Fried Rice with Bacon","calories":730,"protein":19,"carbs":80,"fat":35,"confidence":"medium"}
        (Added ~80 cal for bacon)

        Previous: 800 cal for "burrito bowl with chicken and guac"
        Updated: "burrito bowl with chicken, no guac"
        Result: {"name":"Burrito Bowl","calories":640,"protein":42,"carbs":68,"fat":18,"confidence":"medium"}
        (Removed ~160 cal for guac)

        Now estimate the updated food description above.
        """
    }

    // MARK: - Meal Type Detection Prompt

    /// Builds a prompt to detect the likely meal type from a food description and time of day.
    /// - Parameters:
    ///   - foodDescription: The user's description of what they ate
    ///   - hour: The hour of day (0-23) when the entry was made
    /// - Returns: The formatted prompt string for Gemini
    static func mealTypeDetection(for foodDescription: String, hour: Int) -> String {
        let timeContext: String
        switch hour {
        case 5..<11:
            timeContext = "morning (breakfast time)"
        case 11..<14:
            timeContext = "midday (lunch time)"
        case 14..<17:
            timeContext = "afternoon (snack time)"
        case 17..<21:
            timeContext = "evening (dinner time)"
        default:
            timeContext = "late night"
        }

        return """
        Determine the most likely meal type for this food entry.

        FOOD: "\(foodDescription)"
        TIME: \(timeContext)

        Respond with ONLY one of these exact words: breakfast, lunch, dinner, snack

        Consider both the food type and the time of day. For example:
        - Eggs and toast in the morning = breakfast
        - Sandwich at noon = lunch
        - Small snack items (chips, fruit, candy) = snack
        - Full meal in evening = dinner
        """
    }
}

// MARK: - GeminiService Food Estimation Extension

extension GeminiService {

    /// Estimate calories and macros for a food description, returning itemized food items
    /// - Parameter foodDescription: What the user ate (e.g., "burger, fries, and a coke")
    /// - Returns: A FoodEstimationResult with array of itemized estimates
    func estimateFoodItemized(_ foodDescription: String) async -> FoodEstimationResult {
        let prompt = GeminiPrompts.foodEstimation(for: foodDescription)

        // Use low temperature for consistent, factual responses
        let config = GeminiGenerationConfig(
            temperature: 0.1,
            maxOutputTokens: 512,  // Increased for multiple items
            responseMimeType: "application/json"
        )

        do {
            let jsonResponse = try await generateContent(prompt: prompt, config: config)

            // Use the itemized parser that returns an array
            let estimates = try FoodEstimateParser.parseItemized(jsonResponse, originalDescription: foodDescription)

            return .success(estimates)

        } catch let error as GeminiError {
            parserLogger.error("Gemini API error: \(error.localizedDescription ?? "unknown")")

            // Check if retryable
            if error.isRetryable {
                return .retryable(error: error)
            }

            // For non-retryable errors, suggest manual entry
            return .needsManualEntry(error: error)

        } catch let error as FoodEstimateParseError {
            parserLogger.error("Parse error: \(error.localizedDescription ?? "unknown")")
            // Return a default estimate as single item
            let defaultEstimate = FoodEstimateParser.createDefault(for: foodDescription)
            return .success([defaultEstimate])

        } catch {
            parserLogger.error("Unexpected error: \(error.localizedDescription)")
            let defaultEstimate = FoodEstimateParser.createDefault(for: foodDescription)
            return .success([defaultEstimate])
        }
    }

    /// Estimate calories and macros for a food description (single item result)
    /// Uses the itemized estimation and returns the first item for backward compatibility
    /// - Parameter foodDescription: What the user ate (e.g., "chicken salad with ranch dressing")
    /// - Returns: A SingleFoodEstimationResult for use with recalculation views
    func estimateFoodWithResult(_ foodDescription: String) async -> SingleFoodEstimationResult {
        let result = await estimateFoodItemized(foodDescription)

        switch result {
        case .success(let estimates):
            if let first = estimates.first {
                return .success(first)
            }
            return .success(FoodEstimateParser.createDefault(for: foodDescription))

        case .retryable(let error):
            return .retryable(error: error)

        case .needsManualEntry(let error):
            return .needsManualEntry(error: error)
        }
    }

    /// Estimate calories and macros for a food description
    /// - Parameter foodDescription: What the user ate (e.g., "chicken salad with ranch dressing")
    /// - Returns: A FoodEstimate with nutritional information (uses defaults on error)
    func estimateFood(_ foodDescription: String) async throws -> FoodEstimate {
        let result = await estimateFoodWithResult(foodDescription)

        // Extract estimate from result, or use defaults
        if let estimate = result.estimate {
            return estimate
        }

        // If no estimate (error case), create default
        return FoodEstimateParser.createDefault(for: foodDescription)
    }

    /// Estimate food with option to throw on failure instead of using defaults
    /// - Parameters:
    ///   - foodDescription: What the user ate
    ///   - allowDefaults: If false, throws on parsing failure instead of returning defaults
    /// - Returns: A FoodEstimate with nutritional information
    func estimateFood(_ foodDescription: String, allowDefaults: Bool) async throws -> FoodEstimate {
        if allowDefaults {
            return try await estimateFood(foodDescription)
        }

        let prompt = GeminiPrompts.foodEstimation(for: foodDescription)

        let config = GeminiGenerationConfig(
            temperature: 0.1,
            maxOutputTokens: 256,
            responseMimeType: "application/json"
        )

        let jsonResponse = try await generateContent(prompt: prompt, config: config)
        return try FoodEstimateParser.parse(jsonResponse, originalDescription: foodDescription)
    }

    /// Recalculate nutrition for a modified food entry
    /// Uses context from the original estimate to provide consistent adjustments
    /// - Parameters:
    ///   - newDescription: The updated food description
    ///   - originalCalories: Original calorie estimate
    ///   - originalProtein: Original protein estimate (grams)
    ///   - originalCarbs: Original carbs estimate (grams)
    ///   - originalFat: Original fat estimate (grams)
    /// - Returns: A SingleFoodEstimationResult with the recalculated estimate
    func recalculateFood(
        newDescription: String,
        originalCalories: Int,
        originalProtein: Int,
        originalCarbs: Int,
        originalFat: Int
    ) async -> SingleFoodEstimationResult {
        let prompt = GeminiPrompts.foodRecalculation(
            newDescription: newDescription,
            originalCalories: originalCalories,
            originalProtein: originalProtein,
            originalCarbs: originalCarbs,
            originalFat: originalFat
        )

        print("📝 Recalculate prompt for: \(newDescription)")
        print("   Original: \(originalCalories) cal, \(originalProtein)p, \(originalCarbs)c, \(originalFat)f")

        let config = GeminiGenerationConfig(
            temperature: 0.1,
            maxOutputTokens: 256,
            responseMimeType: "application/json"
        )

        do {
            let jsonResponse = try await generateContent(prompt: prompt, config: config)
            print("📨 API Response: \(jsonResponse)")
            let estimate = try FoodEstimateParser.parse(jsonResponse, originalDescription: newDescription)
            print("📊 Parsed estimate: \(estimate.name) - \(estimate.calories) cal")
            return .success(estimate)

        } catch let error as GeminiError {
            parserLogger.error("Gemini API error during recalculation: \(error.localizedDescription ?? "unknown")")

            if error.isRetryable {
                return .retryable(error: error)
            }
            return .needsManualEntry(error: error)

        } catch let error as FoodEstimateParseError {
            parserLogger.error("Parse error during recalculation: \(error.localizedDescription ?? "unknown")")
            let defaultEstimate = FoodEstimateParser.createDefault(for: newDescription)
            return .success(defaultEstimate)

        } catch {
            parserLogger.error("Unexpected error during recalculation: \(error.localizedDescription)")
            let defaultEstimate = FoodEstimateParser.createDefault(for: newDescription)
            return .success(defaultEstimate)
        }
    }

    /// Detect the likely meal type for a food entry
    /// - Parameters:
    ///   - foodDescription: What the user ate
    ///   - date: When the entry was made (defaults to now)
    /// - Returns: The detected MealType
    func detectMealType(for foodDescription: String, at date: Date = Date()) async throws -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        let prompt = GeminiPrompts.mealTypeDetection(for: foodDescription, hour: hour)

        let config = GeminiGenerationConfig(
            temperature: 0.0,
            maxOutputTokens: 16
        )

        let response = try await generateContent(prompt: prompt, config: config)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch response {
        case "breakfast":
            return .breakfast
        case "lunch":
            return .lunch
        case "dinner":
            return .dinner
        case "snack":
            return .snack
        default:
            // Fall back to time-based detection
            return mealTypeFromHour(hour)
        }
    }

    /// Fallback meal type detection based on time of day
    private func mealTypeFromHour(_ hour: Int) -> MealType {
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<14:
            return .lunch
        case 14..<17:
            return .snack
        case 17..<21:
            return .dinner
        default:
            return .snack
        }
    }
}
