//
//  WalkSessionManagerTests.swift
//  JustWalkTests
//
//  Tests for WalkSessionManager walk control and state management
//

import Testing
import Foundation
@testable import JustWalk

@MainActor
struct WalkSessionManagerTests {

    private let manager = WalkSessionManager.shared

    init() {
        // Reset state if a walk is somehow active
        if manager.isWalking {
            manager.isWalking = false
            manager.isPaused = false
            manager.currentMode = .free
            manager.currentIntervalProgram = nil
            manager.startTime = nil
        }
    }

    // MARK: - Start Walk

    @Test func startWalk_setsIsWalkingTrue() {
        manager.isWalking = false
        manager.startWalk(mode: .free)
        #expect(manager.isWalking == true)

        // Cleanup
        manager.isWalking = false
        manager.startTime = nil
    }

    @Test func startWalk_freeMode_setsModeCorrectly() {
        manager.isWalking = false
        manager.startWalk(mode: .free)
        #expect(manager.currentMode == .free)

        manager.isWalking = false
        manager.startTime = nil
    }

    @Test func startWalk_withInterval_setsIntervalProgram() {
        manager.isWalking = false
        manager.startWalk(mode: .interval, intervalProgram: .medium)
        #expect(manager.currentMode == .interval)
        #expect(manager.currentIntervalProgram == .medium)

        manager.isWalking = false
        manager.startTime = nil
        manager.currentIntervalProgram = nil
    }

    // MARK: - Pause and Resume

    @Test func pauseWalk_setsPausedTrue() {
        manager.isWalking = false
        manager.startWalk(mode: .free)
        manager.pauseWalk()
        #expect(manager.isPaused == true)

        manager.isWalking = false
        manager.isPaused = false
        manager.startTime = nil
    }

    @Test func resumeWalk_setsPausedFalse() {
        manager.isWalking = false
        manager.startWalk(mode: .free)
        manager.pauseWalk()
        #expect(manager.isPaused == true)
        manager.resumeWalk()
        #expect(manager.isPaused == false)

        manager.isWalking = false
        manager.startTime = nil
    }

    // MARK: - End Walk

    @Test func endWalk_returnsTrackedWalkWithCorrectMode() async {
        manager.isWalking = false
        manager.startWalk(mode: .free)

        // Simulate some time passing
        manager.startTime = Date().addingTimeInterval(-600) // 10 minutes ago

        let walk = await manager.endWalk()
        #expect(walk != nil)
        #expect(walk?.mode == .free)
    }

    @Test func endWalk_resetsSessionState() async {
        manager.isWalking = false
        manager.startWalk(mode: .free)
        manager.startTime = Date().addingTimeInterval(-300)

        _ = await manager.endWalk()
        #expect(manager.isWalking == false)
        #expect(manager.isPaused == false)
        #expect(manager.startTime == nil)
        #expect(manager.currentIntervalProgram == nil)
    }

    // MARK: - Start Time

    @Test func startWalk_setsStartTime() {
        manager.isWalking = false
        let before = Date()
        manager.startWalk(mode: .free)
        let after = Date()

        #expect(manager.startTime != nil)
        if let start = manager.startTime {
            #expect(start >= before)
            #expect(start <= after)
        }

        manager.isWalking = false
        manager.startTime = nil
    }
}
