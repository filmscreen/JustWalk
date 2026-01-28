//
//  WalkCompletionIntegrationTests.swift
//  JustWalkTests
//
//  Integration tests for walk completion → DailyLog, streak flow
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct WalkCompletionIntegrationTests {

    private let persistence = PersistenceManager.shared
    private let streakManager = StreakManager.shared

    init() {
        persistence.clearAllData()
        streakManager.streakData = .empty
        streakManager.streakData.consecutiveGoalDays = 0
    }

    // MARK: - Free Walk Completion

    @Test func completeFreeWalk_savedAndLoaded() {
        let walk = TrackedWalk(
            id: UUID(),
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date(),
            durationMinutes: 30,
            steps: 3500,
            distanceMeters: 2400,
            mode: .free,

            intervalProgram: nil,
            intervalCompleted: nil,
            routeCoordinates: []
        )

        persistence.saveTrackedWalk(walk)

        let today = Calendar.current.startOfDay(for: Date())
        let log = DailyLog(id: UUID(), date: today, steps: 3500, goalMet: false, shieldUsed: false, trackedWalkIDs: [walk.id])
        persistence.saveDailyLog(log)

        let loadedLog = persistence.loadDailyLog(for: today)
        #expect(loadedLog?.trackedWalkIDs.contains(walk.id) == true)

        persistence.clearAllData()
    }

    // MARK: - Walk Completion Adds to DailyLog

    @Test func walkCompletion_addsWalkIDToDailyLog() {
        let walkID = UUID()
        let today = Calendar.current.startOfDay(for: Date())

        var log = DailyLog(id: UUID(), date: today, steps: 0, goalMet: false, shieldUsed: false, trackedWalkIDs: [])
        log.trackedWalkIDs.append(walkID)
        persistence.saveDailyLog(log)

        let loaded = persistence.loadDailyLog(for: today)
        #expect(loaded?.trackedWalkIDs.contains(walkID) == true)

        persistence.clearAllData()
    }

    // MARK: - Walk Triggers Streak Check

    @Test func walkCompletion_goalMet_triggersStreakIncrement() {
        streakManager.streakData = .empty
        streakManager.streakData.consecutiveGoalDays = 0

        // Simulate goal met
        streakManager.recordGoalMet(forDate: Date())

        #expect(streakManager.streakData.currentStreak == 1)
        #expect(streakManager.streakData.lastGoalMetDate != nil)

        persistence.clearAllData()
    }

    // MARK: - Walk Data Persists

    @Test func walkData_persistsAndAppearsInQuery() {
        let walkID = UUID()
        let walk = TrackedWalk(
            id: walkID,
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date(),
            durationMinutes: 30,
            steps: 3500,
            distanceMeters: 2400,
            mode: .free,

            intervalProgram: nil,
            intervalCompleted: nil,
            routeCoordinates: []
        )

        persistence.saveTrackedWalk(walk)

        let allWalks = persistence.loadAllTrackedWalks()
        #expect(allWalks.contains { $0.id == walkID })

        let loaded = persistence.loadTrackedWalk(by: walkID)
        #expect(loaded?.durationMinutes == 30)

        persistence.clearAllData()
    }
}
} // extension SharedStateTests
