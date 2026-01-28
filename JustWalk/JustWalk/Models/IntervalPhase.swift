//
//  IntervalPhase.swift
//  JustWalk
//
//  Core data model for interval walk phases
//

import Foundation

struct IntervalPhase: Codable, Identifiable {
    let id: UUID
    let type: PhaseType
    let durationSeconds: Int
    let startOffset: Int // seconds from walk start

    enum PhaseType: String, Codable {
        case warmup
        case fast
        case slow
        case cooldown
    }

    var displayName: String {
        switch type {
        case .warmup: return "Warm Up"
        case .fast: return "Speed Up"
        case .slow: return "Easy Pace"
        case .cooldown: return "Cool Down"
        }
    }

    static func generate(totalMinutes: Int, fastMinutes: Int, slowMinutes: Int) -> [IntervalPhase] {
        var phases: [IntervalPhase] = []
        var offset = 0

        // 1-minute warmup
        phases.append(IntervalPhase(id: UUID(), type: .warmup, durationSeconds: 60, startOffset: offset))
        offset += 60

        // Alternating fast/slow
        while offset < (totalMinutes - 1) * 60 {
            // Fast phase
            let fastDuration = min(fastMinutes * 60, (totalMinutes - 1) * 60 - offset)
            if fastDuration > 0 {
                phases.append(IntervalPhase(id: UUID(), type: .fast, durationSeconds: fastDuration, startOffset: offset))
                offset += fastDuration
            }

            // Slow phase
            let slowDuration = min(slowMinutes * 60, (totalMinutes - 1) * 60 - offset)
            if slowDuration > 0 {
                phases.append(IntervalPhase(id: UUID(), type: .slow, durationSeconds: slowDuration, startOffset: offset))
                offset += slowDuration
            }
        }

        // 1-minute cooldown
        phases.append(IntervalPhase(id: UUID(), type: .cooldown, durationSeconds: 60, startOffset: offset))

        return phases
    }

    /// Generate phases based on exact interval count (for new Short/Medium/Long programs)
    static func generate(intervalCount: Int, fastMinutes: Int, slowMinutes: Int) -> [IntervalPhase] {
        generate(intervalCount: intervalCount, fastMinutes: fastMinutes, slowMinutes: slowMinutes, warmupMinutes: 1, cooldownMinutes: 1)
    }

    /// Generate phases with custom warmup and cooldown durations (for custom interval builder)
    static func generate(
        intervalCount: Int,
        fastMinutes: Int,
        slowMinutes: Int,
        warmupMinutes: Int,
        cooldownMinutes: Int
    ) -> [IntervalPhase] {
        var phases: [IntervalPhase] = []
        var offset = 0

        // Warmup
        let warmupDuration = warmupMinutes * 60
        if warmupDuration > 0 {
            phases.append(IntervalPhase(id: UUID(), type: .warmup, durationSeconds: warmupDuration, startOffset: offset))
            offset += warmupDuration
        }

        // Exact number of fast/slow pairs
        for _ in 0..<intervalCount {
            // Fast phase
            let fastDuration = fastMinutes * 60
            phases.append(IntervalPhase(id: UUID(), type: .fast, durationSeconds: fastDuration, startOffset: offset))
            offset += fastDuration

            // Slow phase
            let slowDuration = slowMinutes * 60
            phases.append(IntervalPhase(id: UUID(), type: .slow, durationSeconds: slowDuration, startOffset: offset))
            offset += slowDuration
        }

        // Cooldown
        let cooldownDuration = cooldownMinutes * 60
        if cooldownDuration > 0 {
            phases.append(IntervalPhase(id: UUID(), type: .cooldown, durationSeconds: cooldownDuration, startOffset: offset))
        }

        return phases
    }
}
