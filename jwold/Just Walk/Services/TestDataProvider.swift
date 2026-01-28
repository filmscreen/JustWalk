//
//  TestDataProvider.swift
//  Just Walk
//
//  Provides mock step data for development and testing.
//  Enable via: UserDefaults "useTestData" = true (DEBUG builds only)
//

import Foundation
import Combine

#if DEBUG

/// Test scenarios for different app states
enum TestScenario: String, CaseIterable {
    case realData = "real_data"         // Use actual HealthKit data
    case newUser = "new_user"           // 0 steps today, no history
    case midDay = "mid_day"             // 4,500 steps, partial week history
    case streakAtRisk = "streak_at_risk" // 8,200 steps, 3 hours until midnight, 14-day streak
    case goalCrushed = "goal_crushed"   // 12,400 steps, goal met
    case streakLost = "streak_lost"     // Yesterday missed, starting fresh today

    var displayName: String {
        switch self {
        case .realData: return "Real Data"
        case .newUser: return "New User"
        case .midDay: return "Mid-Day"
        case .streakAtRisk: return "Streak at Risk"
        case .goalCrushed: return "Goal Crushed"
        case .streakLost: return "Streak Lost"
        }
    }
}

/// Provides mock step data for development and testing
final class TestDataProvider {
    static let shared = TestDataProvider()

    // MARK: - Configuration

    /// Current test scenario
    @Published private(set) var currentScenario: TestScenario = .realData

    /// Whether test data is enabled (only works in DEBUG)
    var isTestDataEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "useTestData") }
        set {
            UserDefaults.standard.set(newValue, forKey: "useTestData")
            if !newValue {
                currentScenario = .realData
            }
        }
    }

    /// Set the current test scenario
    func setScenario(_ scenario: TestScenario) {
        currentScenario = scenario
        if scenario != .realData {
            isTestDataEnabled = true
        }
        // Post notification so views can refresh
        NotificationCenter.default.post(name: .testDataScenarioChanged, object: scenario)
    }

    // MARK: - Today's Steps

    /// Returns today's current steps for the active scenario
    var todaySteps: Int {
        switch currentScenario {
        case .realData:
            return 0 // Shouldn't be called when using real data
        case .newUser:
            return 0
        case .midDay:
            return 4500
        case .streakAtRisk:
            return 8200
        case .goalCrushed:
            return 12400
        case .streakLost:
            return 1200 // Just started walking today
        }
    }

    /// Returns today's distance in meters for the active scenario
    var todayDistance: Double {
        // Approximate: 1 step ≈ 0.762 meters
        return Double(todaySteps) * 0.762
    }

    // MARK: - Current Streak

    /// Returns the mock current streak for the active scenario
    var currentStreak: Int {
        switch currentScenario {
        case .realData:
            return 0
        case .newUser:
            return 0
        case .midDay:
            return 3
        case .streakAtRisk:
            return 14
        case .goalCrushed:
            return 7
        case .streakLost:
            return 0 // Lost yesterday
        }
    }

    // MARK: - Step History

    /// Returns the last N days of daily step history
    func generateStepHistory(days: Int = 30, dailyGoal: Int = 10000) -> [DayStepData] {
        switch currentScenario {
        case .realData:
            return []
        case .newUser:
            return generateNewUserHistory(days: days, dailyGoal: dailyGoal)
        case .midDay:
            return generateMidDayHistory(days: days, dailyGoal: dailyGoal)
        case .streakAtRisk:
            return generateStreakAtRiskHistory(days: days, dailyGoal: dailyGoal)
        case .goalCrushed:
            return generateGoalCrushedHistory(days: days, dailyGoal: dailyGoal)
        case .streakLost:
            return generateStreakLostHistory(days: days, dailyGoal: dailyGoal)
        }
    }

    // MARK: - Scenario Generators

    /// New user: No history
    private func generateNewUserHistory(days: Int, dailyGoal: Int) -> [DayStepData] {
        var history: [DayStepData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            // All zeros for new user
            history.append(DayStepData(
                date: date,
                steps: 0,
                distance: 0,
                historicalGoal: dailyGoal
            ))
        }

        return history
    }

    /// Mid-day: Partial week of activity
    private func generateMidDayHistory(days: Int, dailyGoal: Int) -> [DayStepData] {
        var history: [DayStepData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!

            if dayOffset == 0 {
                // Today: mid-day progress
                history.append(DayStepData(
                    date: date,
                    steps: 4500,
                    distance: 4500 * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else if dayOffset < 7 {
                // Last week: mix of met/missed
                let steps = generateWeightedSteps(dailyGoal: dailyGoal)
                history.append(DayStepData(
                    date: date,
                    steps: steps,
                    distance: Double(steps) * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else {
                // Older: no data (new-ish user)
                history.append(DayStepData(
                    date: date,
                    steps: 0,
                    distance: 0,
                    historicalGoal: dailyGoal
                ))
            }
        }

        return history
    }

    /// Streak at risk: 14-day streak, close to midnight
    private func generateStreakAtRiskHistory(days: Int, dailyGoal: Int) -> [DayStepData] {
        var history: [DayStepData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!

            if dayOffset == 0 {
                // Today: almost there, streak at risk
                history.append(DayStepData(
                    date: date,
                    steps: 8200,
                    distance: 8200 * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else if dayOffset <= 14 {
                // Last 14 days: all goals met (the streak)
                let steps = Int.random(in: dailyGoal...(dailyGoal + 4000))
                history.append(DayStepData(
                    date: date,
                    steps: steps,
                    distance: Double(steps) * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else {
                // Older: mixed history
                let steps = generateWeightedSteps(dailyGoal: dailyGoal)
                history.append(DayStepData(
                    date: date,
                    steps: steps,
                    distance: Double(steps) * 0.762,
                    historicalGoal: dailyGoal
                ))
            }
        }

        return history
    }

    /// Goal crushed: Today's goal exceeded
    private func generateGoalCrushedHistory(days: Int, dailyGoal: Int) -> [DayStepData] {
        var history: [DayStepData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!

            if dayOffset == 0 {
                // Today: goal crushed!
                history.append(DayStepData(
                    date: date,
                    steps: 12400,
                    distance: 12400 * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else if dayOffset <= 7 {
                // Last week: strong streak
                let steps = Int.random(in: dailyGoal...(dailyGoal + 3000))
                history.append(DayStepData(
                    date: date,
                    steps: steps,
                    distance: Double(steps) * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else {
                // Older: mixed
                let steps = generateWeightedSteps(dailyGoal: dailyGoal)
                history.append(DayStepData(
                    date: date,
                    steps: steps,
                    distance: Double(steps) * 0.762,
                    historicalGoal: dailyGoal
                ))
            }
        }

        return history
    }

    /// Streak lost: Yesterday was missed, starting fresh
    private func generateStreakLostHistory(days: Int, dailyGoal: Int) -> [DayStepData] {
        var history: [DayStepData] = []
        let calendar = Calendar.current

        for dayOffset in 0..<days {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!

            if dayOffset == 0 {
                // Today: just starting
                history.append(DayStepData(
                    date: date,
                    steps: 1200,
                    distance: 1200 * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else if dayOffset == 1 {
                // Yesterday: missed! (broke the streak)
                history.append(DayStepData(
                    date: date,
                    steps: 3200,
                    distance: 3200 * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else if dayOffset <= 8 {
                // Previous week: had a 7-day streak going
                let steps = Int.random(in: dailyGoal...(dailyGoal + 2500))
                history.append(DayStepData(
                    date: date,
                    steps: steps,
                    distance: Double(steps) * 0.762,
                    historicalGoal: dailyGoal
                ))
            } else {
                // Older: mixed
                let steps = generateWeightedSteps(dailyGoal: dailyGoal)
                history.append(DayStepData(
                    date: date,
                    steps: steps,
                    distance: Double(steps) * 0.762,
                    historicalGoal: dailyGoal
                ))
            }
        }

        return history
    }

    // MARK: - Helpers

    /// Generates a random step count weighted so ~70% meet goal, ~30% miss
    private func generateWeightedSteps(dailyGoal: Int) -> Int {
        let meetGoal = Double.random(in: 0...1) < 0.7

        if meetGoal {
            // Met goal: between goal and goal + 4000
            return Int.random(in: dailyGoal...(dailyGoal + 4000))
        } else {
            // Missed goal: between 3000 and goal - 1
            return Int.random(in: 3000..<dailyGoal)
        }
    }

    // MARK: - Convenience Methods

    /// Quick toggle for testing
    func enableTestData(scenario: TestScenario = .midDay) {
        setScenario(scenario)
    }

    /// Disable test data and return to real HealthKit data
    func disableTestData() {
        setScenario(.realData)
        isTestDataEnabled = false
    }
}

// MARK: - Notification

extension Notification.Name {
    static let testDataScenarioChanged = Notification.Name("testDataScenarioChanged")
}

#else

// Stub for release builds
final class TestDataProvider {
    static let shared = TestDataProvider()
    var isTestDataEnabled: Bool { false }
    var todaySteps: Int { 0 }
    var todayDistance: Double { 0 }
    var currentStreak: Int { 0 }
    func generateStepHistory(days: Int = 30, dailyGoal: Int = 10000) -> [DayStepData] { [] }
    func setScenario(_ scenario: Any) {}
    func enableTestData(scenario: Any? = nil) {}
    func disableTestData() {}
}

#endif
