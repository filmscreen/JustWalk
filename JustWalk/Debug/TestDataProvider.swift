//
//  TestDataProvider.swift
//  JustWalk
//
//  Injects full synthetic app state for test personas into all managers
//

#if DEBUG
import Foundation

@Observable
final class TestDataProvider {
    static let shared = TestDataProvider()

    private let persistence = PersistenceManager.shared
    private let defaults = UserDefaults.standard

    private static let personaKey = "debug_testPersona"
    private static let syntheticDatesKey = "debug_syntheticLogDates"

    var activePersona: TestPersona {
        didSet {
            defaults.set(activePersona.rawValue, forKey: Self.personaKey)
        }
    }

    var isTestDataActive: Bool {
        activePersona != .realData
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.personaKey) ?? TestPersona.realData.rawValue
        self.activePersona = TestPersona(rawValue: raw) ?? .realData
    }

    // MARK: - Apply Persona

    func applyPersona(_ persona: TestPersona) {
        if persona == .realData {
            revertToRealData()
            return
        }

        activePersona = persona
        let snapshot = buildSnapshot(for: persona)

        // Inject into managers
        StreakManager.shared.streakData = snapshot.streakData
        ShieldManager.shared.shieldData = snapshot.shieldData

        // Persist so views reading from persistence see consistent data
        persistence.saveStreakData(snapshot.streakData)
        persistence.saveShieldData(snapshot.shieldData)

        // Inject tracked walks
        for walk in snapshot.trackedWalks {
            persistence.saveTrackedWalk(walk)
        }

        // Inject daily logs and track which dates are synthetic
        var syntheticDates: [String] = []
        for log in snapshot.dailyLogs {
            persistence.saveDailyLog(log)
            syntheticDates.append(log.dateString)
        }
        defaults.set(syntheticDates, forKey: Self.syntheticDatesKey)

        // Set step override
        HealthKitManager.shared.debugStepOverride = snapshot.todaySteps

        // Set pro status
        if snapshot.isPro {
            SubscriptionManager.shared.setDebugProStatus(true)
        } else {
            SubscriptionManager.shared.setDebugProStatus(false)
        }
    }

    // MARK: - Revert to Real Data

    func revertToRealData() {
        activePersona = .realData

        // Clear step override
        HealthKitManager.shared.debugStepOverride = nil

        // Remove synthetic daily logs
        cleanupSyntheticLogs()

        // Reload real data from persistence
        StreakManager.shared.load()
        ShieldManager.shared.load()

        // Clear debug pro status
        SubscriptionManager.shared.setDebugProStatus(false)
    }

    // MARK: - Cleanup

    private func cleanupSyntheticLogs() {
        guard let syntheticDates = defaults.stringArray(forKey: Self.syntheticDatesKey) else { return }

        // Load all logs, remove synthetic ones, re-save
        let allLogs = persistence.loadAllDailyLogs()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let syntheticSet = Set(syntheticDates)

        // Clear all logs first
        defaults.removeObject(forKey: "daily_logs")
        persistence.dailyLogVersion += 1

        // Re-save only non-synthetic logs
        for log in allLogs {
            if !syntheticSet.contains(log.dateString) {
                persistence.saveDailyLog(log)
            }
        }

        defaults.removeObject(forKey: Self.syntheticDatesKey)
    }

    // MARK: - Snapshot Builder

    private struct PersonaSnapshot {
        let todaySteps: Int
        let streakData: StreakData
        let shieldData: ShieldData
        let dailyLogs: [DailyLog]
        let isPro: Bool
        var trackedWalks: [TrackedWalk] = []
    }

    private func buildSnapshot(for persona: TestPersona) -> PersonaSnapshot {
        switch persona {
        case .realData:
            fatalError("realData should be handled by revertToRealData()")
        case .newUser:
            return buildNewUser()
        case .casualWalker:
            return buildCasualWalker()
        case .streakWarrior:
            return buildStreakWarrior()
        case .streakAtRisk:
            return buildStreakAtRisk()
        case .streakLost:
            return buildStreakLost()
        case .brokenStreakNoShields:
            return buildBrokenStreakNoShields()
        case .brokenStreakWithShields:
            return buildBrokenStreakWithShields()
        }
    }

    // MARK: - New User

    private func buildNewUser() -> PersonaSnapshot {
        PersonaSnapshot(
            todaySteps: 0,
            streakData: .empty,
            shieldData: .empty,
            dailyLogs: [],
            isPro: false
        )
    }

    // MARK: - Casual Walker

    private func buildCasualWalker() -> PersonaSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 3-day streak, goal is 5000
        let streakStart = calendar.date(byAdding: .day, value: -2, to: today)!
        let streakData = StreakData(
            currentStreak: 3,
            longestStreak: 5,
            lastGoalMetDate: calendar.date(byAdding: .day, value: -1, to: today),
            streakStartDate: streakStart
        )

        let shieldData = ShieldData(
            availableShields: 1,
            lastRefillDate: today,
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        // 7 days of mixed history
        var logs: [DailyLog] = []
        let stepPattern = [3_200, 5_100, 0, 5_400, 6_100, 5_300, 4_500]
        let goalMetPattern = [false, true, false, true, true, true, false] // today not yet met
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -(6 - i), to: today)!
            let isToday = i == 6
            logs.append(DailyLog(
                id: UUID(),
                date: date,
                steps: stepPattern[i],
                goalMet: isToday ? false : goalMetPattern[i],
                shieldUsed: false,
                trackedWalkIDs: []
            ))
        }

        return PersonaSnapshot(
            todaySteps: 4_500,
            streakData: streakData,
            shieldData: shieldData,
            dailyLogs: logs,
            isPro: false
        )
    }

    // MARK: - Streak Warrior

    private func buildStreakWarrior() -> PersonaSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 45-day streak, all goals met
        let streakStart = calendar.date(byAdding: .day, value: -44, to: today)!
        let streakData = StreakData(
            currentStreak: 45,
            longestStreak: 45,
            lastGoalMetDate: today,
            streakStartDate: streakStart
        )

        let shieldData = ShieldData(
            availableShields: 3,
            lastRefillDate: today,
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        // 45+ days all met, generate last 45 days
        var logs: [DailyLog] = []
        for i in 0..<45 {
            let date = calendar.date(byAdding: .day, value: -(44 - i), to: today)!
            let steps = Int.random(in: 10_000...14_000)
            logs.append(DailyLog(
                id: UUID(),
                date: date,
                steps: steps,
                goalMet: true,
                shieldUsed: false,
                trackedWalkIDs: []
            ))
        }

        return PersonaSnapshot(
            todaySteps: 11_200,
            streakData: streakData,
            shieldData: shieldData,
            dailyLogs: logs,
            isPro: true
        )
    }

    // MARK: - Streak At Risk

    private func buildStreakAtRisk() -> PersonaSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 14-day streak, today's goal NOT yet met
        let streakStart = calendar.date(byAdding: .day, value: -13, to: today)!
        let streakData = StreakData(
            currentStreak: 14,
            longestStreak: 14,
            lastGoalMetDate: calendar.date(byAdding: .day, value: -1, to: today),
            streakStartDate: streakStart
        )

        let shieldData = ShieldData(
            availableShields: 1,
            lastRefillDate: today,
            shieldsUsedThisMonth: 1,
            purchasedShields: 0
        )

        // 14 days of history, all met except today
        var logs: [DailyLog] = []
        for i in 0..<14 {
            let date = calendar.date(byAdding: .day, value: -(13 - i), to: today)!
            let isToday = i == 13
            let steps = isToday ? 8_200 : Int.random(in: 10_000...13_000)
            logs.append(DailyLog(
                id: UUID(),
                date: date,
                steps: steps,
                goalMet: !isToday,
                shieldUsed: false,
                trackedWalkIDs: []
            ))
        }

        return PersonaSnapshot(
            todaySteps: 8_200,
            streakData: streakData,
            shieldData: shieldData,
            dailyLogs: logs,
            isPro: false
        )
    }

    // MARK: - Streak Lost

    private func buildStreakLost() -> PersonaSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Lost a 32-day streak yesterday — current streak is 0
        let streakData = StreakData(
            currentStreak: 0,
            longestStreak: 32,
            lastGoalMetDate: nil,
            streakStartDate: nil
        )

        let shieldData = ShieldData(
            availableShields: 0,
            lastRefillDate: today,
            shieldsUsedThisMonth: 1,
            purchasedShields: 0
        )

        // 34 days of history: 32 met, yesterday missed, today low
        var logs: [DailyLog] = []
        for i in 0..<34 {
            let date = calendar.date(byAdding: .day, value: -(33 - i), to: today)!
            let isYesterday = i == 32
            let isToday = i == 33

            let steps: Int
            let goalMet: Bool
            if isToday {
                steps = 1_200
                goalMet = false
            } else if isYesterday {
                steps = 2_000
                goalMet = false
            } else {
                steps = Int.random(in: 10_000...13_000)
                goalMet = true
            }

            logs.append(DailyLog(
                id: UUID(),
                date: date,
                steps: steps,
                goalMet: goalMet,
                shieldUsed: false,
                trackedWalkIDs: []
            ))
        }

        return PersonaSnapshot(
            todaySteps: 1_200,
            streakData: streakData,
            shieldData: shieldData,
            dailyLogs: logs,
            isPro: false
        )
    }

    // MARK: - Broken Streak, No Shields (Buy Shield flow)

    private func buildBrokenStreakNoShields() -> PersonaSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Had a 10-day streak, missed 2 days ago, streak broken to 1 (just today)
        let streakData = StreakData(
            currentStreak: 1,
            longestStreak: 10,
            lastGoalMetDate: today,
            streakStartDate: today
        )

        // 0 shields — forces the "Buy Shield" button
        let shieldData = ShieldData(
            availableShields: 0,
            lastRefillDate: today,
            shieldsUsedThisMonth: 1,
            purchasedShields: 0
        )

        // 7-day history: days -6 to -3 met, day -2 missed (repairable), day -1 met, today met
        var logs: [DailyLog] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -(6 - i), to: today)!
            let dayOffset = -(6 - i)

            let steps: Int
            let goalMet: Bool
            if dayOffset == -2 {
                // Missed day — repairable
                steps = 1_800
                goalMet = false
            } else if dayOffset == 0 {
                // Today — goal met
                steps = 7_200
                goalMet = true
            } else {
                steps = Int.random(in: 6_000...9_000)
                goalMet = true
            }

            logs.append(DailyLog(
                id: UUID(),
                date: date,
                steps: steps,
                goalMet: goalMet,
                shieldUsed: false,
                trackedWalkIDs: []
            ))
        }

        return PersonaSnapshot(
            todaySteps: 7_200,
            streakData: streakData,
            shieldData: shieldData,
            dailyLogs: logs,
            isPro: false
        )
    }

    // MARK: - Broken Streak, Has Shields (Use Shield flow)

    private func buildBrokenStreakWithShields() -> PersonaSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Had a 10-day streak, missed 2 days ago, streak broken to 1 (just today)
        let streakData = StreakData(
            currentStreak: 1,
            longestStreak: 10,
            lastGoalMetDate: today,
            streakStartDate: today
        )

        // 2 shields available — shows "Use Streak Shield" button
        let shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: today,
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        // 7-day history: days -6 to -3 met, day -2 missed (repairable), day -1 met, today met
        var logs: [DailyLog] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -(6 - i), to: today)!
            let dayOffset = -(6 - i)

            let steps: Int
            let goalMet: Bool
            if dayOffset == -2 {
                // Missed day — repairable
                steps = 1_800
                goalMet = false
            } else if dayOffset == 0 {
                // Today — goal met
                steps = 7_200
                goalMet = true
            } else {
                steps = Int.random(in: 6_000...9_000)
                goalMet = true
            }

            logs.append(DailyLog(
                id: UUID(),
                date: date,
                steps: steps,
                goalMet: goalMet,
                shieldUsed: false,
                trackedWalkIDs: []
            ))
        }

        return PersonaSnapshot(
            todaySteps: 7_200,
            streakData: streakData,
            shieldData: shieldData,
            dailyLogs: logs,
            isPro: false
        )
    }
}
#endif
