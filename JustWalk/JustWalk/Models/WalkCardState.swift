//
//  WalkCardState.swift
//  JustWalk
//
//  Smart Walk Card state and navigation destination
//

import Foundation

enum WalkCardState: Equatable {
    case patternBased(walkType: WalkMode, usualHour: Int)
    case closeToGoal(stepsRemaining: Int)
    case postMealWindow
    case eveningRescue(stepsRemaining: Int)
    case morningInvitation
    case goalAlreadyMet
    case defaultState
}

enum WalkDestination: Equatable {
    case walkStart(type: WalkMode)
    case walksTab
}

extension WalkCardState {
    var navigationDestination: WalkDestination {
        switch self {
        case .patternBased(let walkType, _):
            return .walkStart(type: walkType)
        case .closeToGoal, .eveningRescue:
            return .walkStart(type: .postMeal)
        case .postMealWindow:
            return .walkStart(type: .postMeal)
        case .morningInvitation:
            return .walkStart(type: .interval)
        case .goalAlreadyMet:
            return .walksTab
        case .defaultState:
            return .walksTab
        }
    }
}
