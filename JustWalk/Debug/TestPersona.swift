//
//  TestPersona.swift
//  JustWalk
//
//  Test personas for debug mode — synthetic app states for rapid UI iteration
//

#if DEBUG
import Foundation

enum TestPersona: String, CaseIterable, Identifiable {
    case realData
    case newUser
    case casualWalker
    case streakWarrior
    case streakAtRisk
    case streakLost
    case brokenStreakNoShields
    case brokenStreakWithShields

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .realData: return "Real Data"
        case .newUser: return "New User"
        case .casualWalker: return "Casual Walker"
        case .streakWarrior: return "Streak Warrior"
        case .streakAtRisk: return "Streak at Risk"
        case .streakLost: return "Streak Lost"
        case .brokenStreakNoShields: return "Broken Streak (Buy Shield)"
        case .brokenStreakWithShields: return "Broken Streak (Has Shields)"
        }
    }

    var description: String {
        switch self {
        case .realData: return "Use actual HealthKit data"
        case .newUser: return "0 steps, no streak, no history"
        case .casualWalker: return "4,500 steps, 3-day streak, partial week"
        case .streakWarrior: return "11,200 steps, 45-day streak, Pro user"
        case .streakAtRisk: return "8,200 steps, 14-day streak, goal pending"
        case .streakLost: return "1,200 steps, just lost a 32-day streak"
        case .brokenStreakNoShields: return "Missed day 2 days ago, 0 shields, needs to buy"
        case .brokenStreakWithShields: return "Missed day 2 days ago, 2 shields available"
        }
    }

    var icon: String {
        switch self {
        case .realData: return "heart.text.square"
        case .newUser: return "person.badge.plus"
        case .casualWalker: return "figure.walk"
        case .streakWarrior: return "flame.fill"
        case .streakAtRisk: return "exclamationmark.triangle.fill"
        case .streakLost: return "heart.slash"
        case .brokenStreakNoShields: return "shield.slash"
        case .brokenStreakWithShields: return "shield.fill"
        }
    }
}
#endif
