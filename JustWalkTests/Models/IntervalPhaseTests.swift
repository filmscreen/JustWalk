//
//  IntervalPhaseTests.swift
//  JustWalkTests
//
//  Tests for interval phase generation and program structure
//

import Testing
@testable import JustWalk

struct IntervalPhaseTests {

    // MARK: - Phase Generation Structure

    @Test func phaseGeneration_warmupIsFirst() {
        let phases = IntervalPhase.generate(intervalCount: 3, fastMinutes: 3, slowMinutes: 3)
        #expect(phases.first?.type == .warmup)
    }

    @Test func phaseGeneration_cooldownIsLast() {
        let phases = IntervalPhase.generate(intervalCount: 3, fastMinutes: 3, slowMinutes: 3)
        #expect(phases.last?.type == .cooldown)
    }

    @Test func phaseGeneration_startOffsetsAreSequential() {
        let phases = IntervalPhase.generate(intervalCount: 5, fastMinutes: 3, slowMinutes: 3)
        for i in 1..<phases.count {
            let expectedOffset = phases[i - 1].startOffset + phases[i - 1].durationSeconds
            #expect(phases[i].startOffset == expectedOffset,
                    "Phase \(i) startOffset \(phases[i].startOffset) != expected \(expectedOffset)")
        }
    }

    // MARK: - All Programs Generate Valid Phases

    @Test(arguments: IntervalProgram.allCases)
    func allPrograms_generateValidPhases(_ program: IntervalProgram) {
        let phases = program.phases
        #expect(!phases.isEmpty)
        #expect(phases.first?.type == .warmup)
        #expect(phases.last?.type == .cooldown)
    }

    @Test(arguments: IntervalProgram.allCases)
    func allPrograms_containFastSlowAlternation(_ program: IntervalProgram) {
        let phases = program.phases
        let innerPhases = phases.dropFirst().dropLast() // Remove warmup/cooldown
        let hasFast = innerPhases.contains { $0.type == .fast }
        let hasSlow = innerPhases.contains { $0.type == .slow }
        #expect(hasFast, "\(program.displayName) should have fast phases")
        #expect(hasSlow, "\(program.displayName) should have slow phases")
    }

    // MARK: - Program Properties

    @Test(arguments: IntervalProgram.allCases)
    func displayName_returnsNonEmptyString(_ program: IntervalProgram) {
        #expect(!program.displayName.isEmpty)
    }

    // MARK: - Specific Program Values

    @Test func short_is18Min() {
        #expect(IntervalProgram.short.duration == 18)
    }

    @Test func medium_is30Min() {
        #expect(IntervalProgram.medium.duration == 30)
    }

    @Test func short_has3Intervals() {
        #expect(IntervalProgram.short.intervalCount == 3)
    }

    @Test func medium_has5Intervals() {
        #expect(IntervalProgram.medium.intervalCount == 5)
    }
}

