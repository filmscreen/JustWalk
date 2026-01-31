//
//  WalkNotificationManagerTests.swift
//  JustWalkTests
//
//  Tests for WalkNotificationManager logic
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct WalkNotificationManagerTests {
    private let manager = WalkNotificationManager.shared
    private let calendar = Calendar.current

    @Test func shouldScheduleToday_goalMet_false() {
        let state = WalkNotificationState.empty
        let now = date(hour: 18, minute: 0)
        let should = manager.shouldScheduleToday(
            now: now,
            goal: 7000,
            currentSteps: 8000,
            notificationsAllowed: true,
            state: state,
            force: false,
            calendar: calendar
        )
        #expect(should == false)
    }

    @Test func shouldScheduleToday_afterWindow_false() {
        let state = WalkNotificationState.empty
        let now = date(hour: 22, minute: 0)
        let should = manager.shouldScheduleToday(
            now: now,
            goal: 7000,
            currentSteps: 3000,
            notificationsAllowed: true,
            state: state,
            force: false,
            calendar: calendar
        )
        #expect(should == false)
    }

    @Test func computeOptimalNotificationTime_patternClamped() {
        let now = date(hour: 10, minute: 0)
        let target = manager.computeOptimalNotificationTime(
            now: now,
            stepsRemaining: 4000,
            typicalHour: 15,
            preferredTime: nil,
            smartTimingEnabled: true,
            calendar: calendar
        )
        #expect(calendar.component(.hour, from: target ?? now) == 17)
    }

    @Test func computeOptimalNotificationTime_preferredTimeUsed() {
        let now = date(hour: 12, minute: 0)
        let preferred = date(hour: 20, minute: 15)
        let target = manager.computeOptimalNotificationTime(
            now: now,
            stepsRemaining: 3000,
            typicalHour: nil,
            preferredTime: preferred,
            smartTimingEnabled: false,
            calendar: calendar
        )
        #expect(calendar.component(.hour, from: target ?? now) == 20)
        #expect(calendar.component(.minute, from: target ?? now) == 15)
    }

    @Test func selectNotificationContent_closeToGoal() {
        let content = manager.selectNotificationContent(
            stepsRemaining: 800,
            currentStreak: 2,
            typicalWalkHour: nil,
            preferredWalkType: .postMeal
        )
        #expect(content.title.contains("close"))
    }

    private func date(hour: Int, minute: Int) -> Date {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var components = calendar.dateComponents([.year, .month, .day], from: base)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? base
    }
}
}
