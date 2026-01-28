//
//  Just_WalkTests.swift
//  Just WalkTests
//
//  Created by Randy Chia on 1/8/26.
//

import XCTest
@testable import Just_Walk

@MainActor
final class IWTServiceTests: XCTestCase {

    var service: IWTService!
    
    override func setUp() {
        super.setUp()
        service = IWTService.shared
    }
    
    override func tearDown() {
        if service.isSessionActive {
            _ = service.endSession()
        }
        service = nil
        super.tearDown()
    }
    
    func testSessionStart() {
        service.startSession(mode: .interval, with: .beginner)

        XCTAssertTrue(service.isSessionActive)
        XCTAssertFalse(service.isPaused)
        XCTAssertEqual(service.currentPhase, .warmup)
        XCTAssertEqual(service.currentInterval, 0)
        XCTAssertEqual(service.phaseTimeRemaining, IWTConfiguration.beginner.warmupDuration)
    }

    func testPauseResume() {
        service.startSession(mode: .interval, with: .beginner)
        
        service.pauseSession()
        XCTAssertTrue(service.isPaused)
        XCTAssertEqual(service.currentPhase, .paused)
        
        service.resumeSession()
        XCTAssertFalse(service.isPaused)
        XCTAssertEqual(service.currentPhase, .warmup) // Should return to previous phase
    }
    
    func testPhaseTransitions() {
        service.startSession(mode: .interval, with: .beginner)
        
        // Warmup -> Brisk (Interval 1)
        service.skipToNextPhase()
        XCTAssertEqual(service.currentPhase, .brisk)
        XCTAssertEqual(service.currentInterval, 1)
        
        // Brisk -> Slow
        service.skipToNextPhase()
        XCTAssertEqual(service.currentPhase, .slow)
        XCTAssertEqual(service.completedBriskIntervals, 1)
        
        // Slow -> Brisk (Interval 2)
        service.skipToNextPhase()
        XCTAssertEqual(service.currentPhase, .brisk)
        XCTAssertEqual(service.currentInterval, 2)
        XCTAssertEqual(service.completedSlowIntervals, 1)
    }
    
    func testFullSessionCycle() {
        // Use a config with few intervals for easier testing
        let config = IWTConfiguration(
            briskDuration: 1,
            slowDuration: 1,
            warmupDuration: 1,
            cooldownDuration: 1,
            totalIntervals: 2,
            enableWarmup: true,
            enableCooldown: true
        )

        service.startSession(mode: .interval, with: config)
        
        // Warmup -> Brisk 1
        service.skipToNextPhase()
        XCTAssertEqual(service.currentPhase, .brisk)
        
        // Brisk 1 -> Slow 1
        service.skipToNextPhase()
        
        // Slow 1 -> Brisk 2
        service.skipToNextPhase()
        XCTAssertEqual(service.currentPhase, .brisk)
        
        // Brisk 2 -> Slow 2
        service.skipToNextPhase()
        
        // Slow 2 -> Cooldown (since totalIntervals is 2)
        service.skipToNextPhase()
        XCTAssertEqual(service.currentPhase, .cooldown)
        
        // Cooldown -> Completed
        service.skipToNextPhase()
        XCTAssertEqual(service.currentPhase, .completed)
    }
    
    func testSessionSummary() {
        service.startSession(mode: .interval)

        // Simulate some progress
        service.skipToNextPhase() // Warmup -> Brisk
        service.skipToNextPhase() // Brisk -> Slow
        
        let summary = service.endSession()
        
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.briskIntervals, 1)
        XCTAssertFalse(service.isSessionActive)
    }
}
