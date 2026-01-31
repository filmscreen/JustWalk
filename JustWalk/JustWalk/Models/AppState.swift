//
//  AppState.swift
//  JustWalk
//
//  Observable app state for SwiftUI
//

import Foundation
import SwiftUI

enum AppTab: String, CaseIterable {
    case today
    case walks = "intervals" // renamed from "intervals", raw value preserved for stored state
    case fuel = "eat" // renamed from "eat", raw value preserved for stored state
    case settings
}

@Observable
class AppState {
    var profile: UserProfile = .default
    var streakData: StreakData = .empty
    var shieldData: ShieldData = .empty
    var todayLog: DailyLog?

    var isWalking: Bool = false
    var currentWalkStartTime: Date?

    var selectedTab: AppTab = .today

    /// Set by TodayView when a dynamic card action fires; consumed by WalksHomeView
    var pendingCardAction: CardAction? = nil

    var healthKitDenied: Bool = false

    /// Tracks whether the user is currently viewing the active walk screen
    /// Set by WalkTabView when showing WalkActiveView
    var isViewingActiveWalk: Bool = false
}
