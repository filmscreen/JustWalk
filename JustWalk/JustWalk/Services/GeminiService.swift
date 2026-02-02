//
//  GeminiService.swift
//  JustWalk
//
//  Service for making requests to the Gemini AI API
//  Used for AI-powered food logging and nutritional analysis
//

import Foundation
import Combine
import os.log

private let geminiLogger = Logger(subsystem: "onworldtech.JustWalk", category: "GeminiService")

// MARK: - Gemini Error Types

enum GeminiError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case apiError(message: String)
    case noContent
    case rateLimited
    case parseError(String)
    case timeout
    case cancelled

    /// Technical description for logging
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .noContent:
            return "No content in response"
        case .rateLimited:
            return "Rate limited by API"
        case .parseError(let details):
            return "Parse error: \(details)"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request was cancelled"
        }
    }

    /// User-friendly message to display in the UI
    var userMessage: String {
        switch self {
        case .invalidURL:
            return "Something went wrong. Please try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .invalidResponse, .decodingError, .noContent, .parseError:
            return "Couldn't process the response. You can enter details manually."
        case .httpError(let statusCode):
            if statusCode >= 500 {
                return "The service is temporarily unavailable. Please try again later."
            }
            return "Something went wrong. Please try again."
        case .apiError:
            return "The AI service encountered an issue. You can enter details manually."
        case .rateLimited:
            return "Please wait a moment and try again."
        case .timeout:
            return "The request took too long. Please try again."
        case .cancelled:
            return "Request was cancelled."
        }
    }

    /// Whether the user should be offered manual entry as a fallback
    var shouldOfferManualEntry: Bool {
        switch self {
        case .rateLimited:
            return false  // User should just wait and retry
        case .cancelled:
            return false  // User cancelled, don't prompt
        case .timeout:
            return true   // User can enter manually if request is slow
        case .networkError:
            return true   // User can enter manually while offline
        default:
            return true   // Always offer manual entry as fallback
        }
    }

    /// Whether the error is transient and the user should retry
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .networkError, .timeout:
            return true
        case .cancelled:
            return false  // User chose to cancel
        case .httpError(let statusCode):
            return statusCode >= 500  // Server errors are retryable
        default:
            return false
        }
    }
}

// MARK: - Gemini Request/Response Models

struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?

    init(prompt: String, generationConfig: GeminiGenerationConfig? = nil) {
        self.contents = [GeminiContent(parts: [GeminiPart(text: prompt)])]
        self.generationConfig = generationConfig
    }
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?

    init(parts: [GeminiPart], role: String? = nil) {
        self.parts = parts
        self.role = role
    }
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Encodable {
    let temperature: Double?
    let topK: Int?
    let topP: Double?
    let maxOutputTokens: Int?
    let responseMimeType: String?

    init(
        temperature: Double? = nil,
        topK: Int? = nil,
        topP: Double? = nil,
        maxOutputTokens: Int? = nil,
        responseMimeType: String? = nil
    ) {
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.maxOutputTokens = maxOutputTokens
        self.responseMimeType = responseMimeType
    }
}

struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]?
    let promptFeedback: GeminiPromptFeedback?
    let error: GeminiAPIError?
}

struct GeminiCandidate: Decodable {
    let content: GeminiContent?
    let finishReason: String?
    let safetyRatings: [GeminiSafetyRating]?
}

struct GeminiPromptFeedback: Decodable {
    let safetyRatings: [GeminiSafetyRating]?
    let blockReason: String?
}

struct GeminiSafetyRating: Decodable {
    let category: String
    let probability: String
}

struct GeminiAPIError: Decodable {
    let code: Int
    let message: String
    let status: String?
}

// MARK: - Gemini Service

@MainActor
final class GeminiService: ObservableObject {
    static let shared = GeminiService()

    // API Configuration - key loaded from Info.plist (set via Secrets.xcconfig)
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    // State
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: GeminiError?

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        // Load API key from Info.plist (set via Secrets.xcconfig build setting)
        if let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
           !key.isEmpty,
           !key.hasPrefix("$(") {
            self.apiKey = key
        } else {
            geminiLogger.error("GEMINI_API_KEY not found in Info.plist. See Secrets.xcconfig.template for setup instructions.")
            self.apiKey = ""
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        geminiLogger.info("GeminiService initialized")
    }

    // MARK: - Public API

    /// Send a prompt to Gemini and get the text response
    /// - Parameters:
    ///   - prompt: The text prompt to send
    ///   - config: Optional generation configuration
    /// - Returns: The text response from Gemini
    func generateContent(prompt: String, config: GeminiGenerationConfig? = nil) async throws -> String {
        geminiLogger.info("Generating content with prompt length: \(prompt.count)")

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        // Build URL with API key
        guard var urlComponents = URLComponents(string: baseURL) else {
            let error = GeminiError.invalidURL
            lastError = error
            throw error
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            let error = GeminiError.invalidURL
            lastError = error
            throw error
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let geminiRequest = GeminiRequest(prompt: prompt, generationConfig: config)

        do {
            request.httpBody = try encoder.encode(geminiRequest)
        } catch {
            let geminiError = GeminiError.decodingError(error)
            lastError = geminiError
            throw geminiError
        }

        // Make request
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Check for specific error types
            let nsError = error as NSError

            // Check for cancellation (Swift concurrency or URLSession)
            if error is CancellationError || nsError.code == NSURLErrorCancelled {
                let geminiError = GeminiError.cancelled
                lastError = geminiError
                geminiLogger.info("Request was cancelled")
                throw geminiError
            }

            // Check for timeout
            if nsError.code == NSURLErrorTimedOut {
                let geminiError = GeminiError.timeout
                lastError = geminiError
                geminiLogger.warning("Request timed out")
                throw geminiError
            }

            // Generic network error
            let geminiError = GeminiError.networkError(error)
            lastError = geminiError
            geminiLogger.error("Network error: \(error.localizedDescription)")
            throw geminiError
        }

        // Check HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            let error = GeminiError.invalidResponse
            lastError = error
            throw error
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Check for rate limiting first
            if httpResponse.statusCode == 429 {
                let error = GeminiError.rateLimited
                lastError = error
                geminiLogger.warning("Rate limited by Gemini API")
                throw error
            }

            // Try to decode error response
            if let errorResponse = try? decoder.decode(GeminiResponse.self, from: data),
               let apiError = errorResponse.error {
                let error = GeminiError.apiError(message: apiError.message)
                lastError = error
                geminiLogger.error("API error: \(apiError.message)")
                throw error
            }

            let error = GeminiError.httpError(statusCode: httpResponse.statusCode)
            lastError = error
            geminiLogger.error("HTTP error: \(httpResponse.statusCode)")
            throw error
        }

        // Decode response
        let geminiResponse: GeminiResponse
        do {
            geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
        } catch {
            let geminiError = GeminiError.decodingError(error)
            lastError = geminiError
            geminiLogger.error("Decoding error: \(error.localizedDescription)")
            throw geminiError
        }

        // Check for API-level errors
        if let apiError = geminiResponse.error {
            let error = GeminiError.apiError(message: apiError.message)
            lastError = error
            throw error
        }

        // Check for blocked content
        if let feedback = geminiResponse.promptFeedback,
           let blockReason = feedback.blockReason {
            let error = GeminiError.apiError(message: "Content blocked: \(blockReason)")
            lastError = error
            throw error
        }

        // Extract text from response
        guard let candidates = geminiResponse.candidates,
              let firstCandidate = candidates.first,
              let content = firstCandidate.content,
              let textPart = content.parts.first else {
            let error = GeminiError.noContent
            lastError = error
            throw error
        }

        // Track API usage
        APIUsageTracker.shared.recordAPICall()

        geminiLogger.info("Successfully received response with \(textPart.text.count) characters")
        return textPart.text
    }

    /// Generate content with JSON response format
    /// - Parameters:
    ///   - prompt: The text prompt to send
    ///   - temperature: Controls randomness (0.0 to 1.0)
    /// - Returns: The text response (expected to be JSON)
    func generateJSON(prompt: String, temperature: Double = 0.2) async throws -> String {
        let config = GeminiGenerationConfig(
            temperature: temperature,
            maxOutputTokens: 1024,
            responseMimeType: "application/json"
        )
        return try await generateContent(prompt: prompt, config: config)
    }

    /// Test the API connection
    /// - Returns: true if the API is reachable and responding
    func testConnection() async -> Bool {
        do {
            let response = try await generateContent(prompt: "Say 'OK' if you can hear me.")
            geminiLogger.info("Test connection successful: \(response.prefix(50))")
            return true
        } catch {
            geminiLogger.error("Test connection failed: \(error.localizedDescription)")
            return false
        }
    }
}
