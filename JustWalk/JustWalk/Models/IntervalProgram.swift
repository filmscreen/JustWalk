//
//  IntervalProgram.swift
//  JustWalk
//
//  Enum for predefined interval walking programs
//

import Foundation

enum IntervalProgram: String, Codable, CaseIterable, Identifiable {
    case short
    case medium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .short: return "Quick"
        case .medium: return "Standard"
        }
    }

    var isRecommended: Bool {
        self == .medium
    }

    var structureLabel: String {
        "\(fastMinutes) min fast / \(slowMinutes) min slow"
    }

    /// Advertised duration (slightly less than actual for marketing)
    var duration: Int { // minutes
        switch self {
        case .short: return 18   // Actual: 20 min
        case .medium: return 30  // Actual: 32 min
        }
    }

    var cardLabel: String {
        switch self {
        case .short: return "Quick"
        case .medium: return "Standard"
        }
    }

    var description: String {
        switch self {
        case .short: return "For busy days"
        case .medium: return "The original Japanese method"
        }
    }

    /// Number of fast/slow interval pairs
    var intervalCount: Int {
        switch self {
        case .short: return 3
        case .medium: return 5
        }
    }

    var fastMinutes: Int { 3 }

    var slowMinutes: Int { 3 }

    /// Cached phases to ensure stable UUIDs (prevents repeated audio cues)
    private static var cachedPhases: [IntervalProgram: [IntervalPhase]] = [:]

    var phases: [IntervalPhase] {
        if let cached = Self.cachedPhases[self] {
            return cached
        }
        let generated = IntervalPhase.generate(
            intervalCount: intervalCount,
            fastMinutes: fastMinutes,
            slowMinutes: slowMinutes
        )
        Self.cachedPhases[self] = generated
        return generated
    }

    /// Clears cached phases (call when starting a new session to get fresh UUIDs)
    static func resetCachedPhases() {
        cachedPhases.removeAll()
    }
}

