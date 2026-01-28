//
//  CustomIntervalConfig.swift
//  JustWalk
//
//  Custom interval configuration for Pro users
//

import Foundation

struct CustomIntervalConfig: Codable, Identifiable {
    let id: UUID
    let fastMinutes: Int
    let slowMinutes: Int
    let warmupMinutes: Int
    let cooldownMinutes: Int
    let intervalCount: Int
    
    /// Pre-generated phases with stable UUIDs (prevents repeated audio cues)
    let phases: [IntervalPhase]

    init(
        fastMinutes: Int = 3,
        slowMinutes: Int = 3,
        warmupMinutes: Int = 1,
        cooldownMinutes: Int = 1,
        intervalCount: Int = 3
    ) {
        self.id = UUID()
        self.fastMinutes = fastMinutes
        self.slowMinutes = slowMinutes
        self.warmupMinutes = warmupMinutes
        self.cooldownMinutes = cooldownMinutes
        self.intervalCount = intervalCount
        
        // Generate phases once at init with stable UUIDs
        self.phases = IntervalPhase.generate(
            intervalCount: intervalCount,
            fastMinutes: fastMinutes,
            slowMinutes: slowMinutes,
            warmupMinutes: warmupMinutes,
            cooldownMinutes: cooldownMinutes
        )
    }

    /// Total time is auto-calculated from the components
    var totalMinutes: Int {
        warmupMinutes + (intervalCount * (fastMinutes + slowMinutes)) + cooldownMinutes
    }

    var displayName: String { "Custom" }

    var cycleCount: Int { intervalCount }
}
