//
//  DailyLogTests.swift
//  JustWalkTests
//
//  Tests for DailyLog model
//

import Testing
import Foundation
@testable import JustWalk

struct DailyLogTests {

    @Test func defaultDailyLog_hasZeroStepsAndGoalNotMet() {
        let log = DailyLog(
            id: UUID(),
            date: Date(),
            steps: 0,
            goalMet: false,
            shieldUsed: false,
            
            trackedWalkIDs: []
        )
        #expect(log.steps == 0)
        #expect(log.goalMet == false)
        #expect(log.trackedWalkIDs.isEmpty)
    }

    @Test func addingWalkIDs_persists() {
        let walkID1 = UUID()
        let walkID2 = UUID()
        var log = DailyLog(
            id: UUID(),
            date: Date(),
            steps: 0,
            goalMet: false,
            shieldUsed: false,
            
            trackedWalkIDs: [walkID1]
        )
        log.trackedWalkIDs.append(walkID2)
        #expect(log.trackedWalkIDs.count == 2)
        #expect(log.trackedWalkIDs.contains(walkID1))
        #expect(log.trackedWalkIDs.contains(walkID2))
    }

    @Test func goalMetFlag_toggles() {
        var log = DailyLog(
            id: UUID(),
            date: Date(),
            steps: 5000,
            goalMet: false,
            shieldUsed: false,
            
            trackedWalkIDs: []
        )
        #expect(log.goalMet == false)
        log.goalMet = true
        #expect(log.goalMet == true)
    }

    @Test func shieldUsedFlag_toggles() {
        var log = DailyLog(
            id: UUID(),
            date: Date(),
            steps: 0,
            goalMet: false,
            shieldUsed: false,
            
            trackedWalkIDs: []
        )
        #expect(log.shieldUsed == false)
        log.shieldUsed = true
        #expect(log.shieldUsed == true)
    }

    @Test func codableRoundTrip() throws {
        let original = DailyLog(
            id: UUID(),
            date: Date(),
            steps: 7500,
            goalMet: true,
            shieldUsed: false,
            trackedWalkIDs: [UUID(), UUID()]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(DailyLog.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.steps == original.steps)
        #expect(decoded.goalMet == original.goalMet)
        #expect(decoded.trackedWalkIDs == original.trackedWalkIDs)
    }
}
