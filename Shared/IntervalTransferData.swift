//
//  IntervalTransferData.swift
//  JustWalk
//
//  Shared Codable struct for transferring interval data between iPhone and Watch
//

import Foundation

struct IntervalTransferData: Codable {
    let programName: String
    let totalDurationSeconds: Int
    let phases: [IntervalPhaseData]
}

struct IntervalPhaseData: Codable {
    let type: String // "warmup", "fast", "slow", "cooldown"
    let durationSeconds: Int
    let startOffset: Int
}
