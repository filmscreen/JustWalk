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
    /// Valid calorie range (0 to 10,000)
    static let calorieRange = 0...10000

    /// Valid macro range in grams (0 to 1,000)
    static let macroRange = 0...1000

    /// Maximum name length
    static let maxNameLength = 100

    /// Default values for missing/invalid fields
    static let defaultName = "Food Entry"
    static let defaultCalories = 200
    static let defaultProtein = 10
    static let defaultCarbs = 25
    static let defaultFat = 8
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
}

// MARK: - Food Estimation Result

/// Result of attempting to estimate food nutrition via AI
/// Provides a unified interface for views to handle all outcomes gracefully
enum FoodEstimationResult {
    /// Successful estimation from AI
    case success(FoodEstimate)

    /// AI returned a result but with low confidence - user should verify
    case successLowConfidence(FoodEstimate)

    /// Using default values because AI couldn't provide a good estimate
    case usingDefaults(FoodEstimate, reason: String)

    /// Error occurred but user can retry
    case retryable(error: GeminiError)

    /// Error occurred - user should enter manually
    case needsManualEntry(error: GeminiError)

    /// The estimate to use (available in all success cases)
    var estimate: FoodEstimate? {
        switch self {
        case .success(let estimate),
             .successLowConfidence(let estimate),
             .usingDefaults(let estimate, _):
            return estimate
        case .retryable, .needsManualEntry:
            return nil
        }
    }

    /// User-friendly message describing the result
    var userMessage: String? {
        switch self {
        case .success:
            return nil  // No message needed for clean success
        case .successLowConfidence:
            return "This is a rough estimate. You can adjust if needed."
        case .usingDefaults(_, let reason):
            return reason
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

    /// Whether the user should be prompted to enter manually
    var shouldShowManualEntry: Bool {
        switch self {
        case .success, .successLowConfidence:
            return false
        case .usingDefaults:
            return true  // Offer to refine the defaults
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
@MainActor
@Observable
final class FoodEstimationState {

    // MARK: - State

    /// Current phase of the estimation
    enum Phase: Equatable {
        case idle
        case loading(message: String)
        case success(FoodEstimate)
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

    /// The successful estimate, if available
    var estimate: FoodEstimate? {
        if case .success(let estimate) = phase { return estimate }
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

            // Perform the estimation
            let result = await GeminiService.shared.estimateFoodWithResult(description)

            // Cancel the message update task
            messageTask.cancel()

            // Check for cancellation again
            guard !Task.isCancelled else {
                phase = .idle
                return
            }

            // Handle the result
            switch result {
            case .success(let estimate), .successLowConfidence(let estimate):
                phase = .success(estimate)

            case .usingDefaults(let estimate, _):
                // Use defaults but still show as success
                phase = .success(estimate)

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
    func setEstimate(_ estimate: FoodEstimate) {
        cancel()
        foodDescription = estimate.description
        phase = .success(estimate)
    }
}

// MARK: - Gemini Prompts

enum GeminiPrompts {

    // MARK: - Food Estimation Prompt

    /// Builds a prompt for estimating calories and macronutrients from a food description.
    /// - Parameter foodDescription: The user's description of what they ate
    /// - Returns: The formatted prompt string for Gemini
    static func foodEstimation(for foodDescription: String) -> String {
        """
        You are a nutritionist assistant helping users track their food intake. Estimate the calories and macronutrients for the following food description.

        FOOD DESCRIPTION:
        "\(foodDescription)"

        INSTRUCTIONS:
        1. Provide realistic, conservative estimates based on typical serving sizes
        2. If the description is vague, assume a standard/moderate portion
        3. Round all numbers to reasonable integers
        4. For "name", create a short (2-4 words) display name
        5. Set confidence based on how specific the description is:
           - "high": Specific food with portion size (e.g., "2 eggs scrambled")
           - "medium": Specific food without portion (e.g., "scrambled eggs")
           - "low": Vague description (e.g., "some breakfast")
        6. Add a brief note only if there's important context (e.g., estimation assumptions)

        Respond with ONLY valid JSON in this exact format, no markdown, no explanation:
        {
          "name": "short display name",
          "calories": 0,
          "protein": 0,
          "carbs": 0,
          "fat": 0,
          "confidence": "low",
          "notes": null
        }

        EXAMPLES:

        Input: "chipotle burrito bowl with chicken, rice, black beans, corn salsa, cheese, and guac"
        Output: {"name":"Chipotle Bowl","calories":785,"protein":42,"carbs":68,"fat":32,"confidence":"high","notes":null}

        Input: "a sandwich"
        Output: {"name":"Sandwich","calories":350,"protein":15,"carbs":40,"fat":12,"confidence":"low","notes":"Assumed standard deli sandwich"}

        Input: "large pepperoni pizza from dominos, ate half"
        Output: {"name":"Half Pepperoni Pizza","calories":1120,"protein":48,"carbs":112,"fat":52,"confidence":"high","notes":"4 slices of large pizza"}

        Now estimate for the food description above.
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

    /// Estimate calories and macros for a food description with comprehensive error handling
    /// - Parameter foodDescription: What the user ate (e.g., "chicken salad with ranch dressing")
    /// - Returns: A FoodEstimationResult indicating success, partial success, or error with context
    func estimateFoodWithResult(_ foodDescription: String) async -> FoodEstimationResult {
        let prompt = GeminiPrompts.foodEstimation(for: foodDescription)

        // Use low temperature for consistent, factual responses
        let config = GeminiGenerationConfig(
            temperature: 0.1,
            maxOutputTokens: 256,
            responseMimeType: "application/json"
        )

        do {
            let jsonResponse = try await generateContent(prompt: prompt, config: config)

            // Use the robust parser that handles malformed JSON and provides defaults
            let estimate = try FoodEstimateParser.parse(jsonResponse, originalDescription: foodDescription)

            // Check confidence level
            if estimate.confidence == .low {
                return .successLowConfidence(estimate)
            }
            return .success(estimate)

        } catch let error as GeminiError {
            parserLogger.error("Gemini API error: \(error.localizedDescription ?? "unknown")")

            // Check if retryable
            if error.isRetryable {
                return .retryable(error: error)
            }

            // For non-retryable errors, provide default estimate if appropriate
            if error.shouldOfferManualEntry {
                return .needsManualEntry(error: error)
            }

            // Fallback with defaults
            let defaultEstimate = FoodEstimateParser.createDefault(for: foodDescription)
            return .usingDefaults(defaultEstimate, reason: error.userMessage)

        } catch let error as FoodEstimateParseError {
            parserLogger.error("Parse error: \(error.localizedDescription ?? "unknown")")
            let defaultEstimate = FoodEstimateParser.createDefault(for: foodDescription)
            return .usingDefaults(defaultEstimate, reason: "Couldn't understand the AI response. Using estimated values.")

        } catch {
            parserLogger.error("Unexpected error: \(error.localizedDescription)")
            let defaultEstimate = FoodEstimateParser.createDefault(for: foodDescription)
            return .usingDefaults(defaultEstimate, reason: "Something went wrong. Using estimated values.")
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
