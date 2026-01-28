//
//  WalkSummaryViewModel.swift
//  Just Walk
//
//  ViewModel for post-walk summary screens.
//  Manages goal progress, time saved calculations, and conversion triggers.
//

import Foundation
import Combine
import CoreLocation

/// Data model for walk summary display
struct WalkSummaryData {
    let sessionSummary: IWTSessionSummary
    let stepsBeforeWalk: Int
    let dailyGoal: Int
    let walkMode: WalkMode
    let routeCoordinates: [CLLocationCoordinate2D]

    var stepsAdded: Int { sessionSummary.steps }
    var stepsAfterWalk: Int { stepsBeforeWalk + sessionSummary.steps }

    var didReachGoalDuringWalk: Bool {
        stepsAfterWalk >= dailyGoal && stepsBeforeWalk < dailyGoal
    }

    var wasGoalAlreadyReached: Bool {
        stepsBeforeWalk >= dailyGoal
    }

    var goalProgressBefore: Double {
        min(1.0, Double(stepsBeforeWalk) / Double(dailyGoal))
    }

    var goalProgressAfter: Double {
        min(1.0, Double(stepsAfterWalk) / Double(dailyGoal))
    }

    var completedSuccessfully: Bool {
        sessionSummary.completedSuccessfully
    }

    var completedIntervals: Int {
        sessionSummary.briskIntervals
    }

    var totalIntervals: Int {
        sessionSummary.configuration.totalIntervals
    }
}

/// ViewModel for WalkSummaryView
@MainActor
final class WalkSummaryViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var summaryData: WalkSummaryData
    @Published private(set) var estimatedTimeSaved: Int = 0
    @Published private(set) var estimatedPowerWalkDuration: TimeInterval = 0
    @Published private(set) var shouldShowConversionCard: Bool = false
    @Published private(set) var powerWalksThisWeek: Int = 0
    @Published var conversionCardDismissed: Bool = false

    // MARK: - Encouragement Messages

    private let justWalkEncouragements = [
        "Every step brings you closer to your goal.",
        "You showed up today. That's what matters.",
        "Consistency beats intensity. Keep walking.",
        "Your future self will thank you."
    ]

    private let powerWalkCompletedEncouragements = [
        "You did what most people won't. Be proud.",
        "That's the kind of effort that builds habits.",
        "Interval training: more results, less time.",
        "Your consistency is paying off."
    ]

    private let powerWalkEndedEarlyEncouragements = [
        "Partial workouts still count. You showed up.",
        "Some days are harder than others.",
        "Progress isn't always linear.",
        "You can always try again tomorrow."
    ]

    // MARK: - Initialization

    init(summaryData: WalkSummaryData) {
        self.summaryData = summaryData
        calculateDerivedValues()
        trackCompletion()
    }

    // MARK: - Computed Properties

    /// Whether this was a meaningful walk (has enough steps to show full summary)
    var isEmptyWalk: Bool {
        summaryData.stepsAdded == 0
    }

    var headerText: String {
        // Goal hit during walk takes highest priority
        if summaryData.didReachGoalDuringWalk {
            return "Goal Crushed!"
        }

        // Power Walk has interval-based messaging
        if summaryData.walkMode == .interval {
            return powerWalkHeadline
        }

        // Just Walk uses step-based messaging
        switch summaryData.stepsAdded {
        case 0:
            return "Walk Ended"
        case 1..<500:
            return "Quick One!"
        case 500..<2000:
            return "Nice Walk!"
        case 2000..<5000:
            return "Great Walk!"
        default:
            return "Amazing Walk!"
        }
    }

    /// Power Walk headline based on intervals completed
    private var powerWalkHeadline: String {
        let completed = summaryData.completedIntervals

        // All intervals completed
        if summaryData.completedSuccessfully {
            return "Power Walk Complete! 🎉"
        }

        // No intervals completed
        if completed == 0 {
            return "Walk Recorded"
        }

        // Partial completion based on count
        switch completed {
        case 1...2:
            return "Good Start!"
        case 3...4:
            return "Nice Effort!"
        default: // 5+
            return "Great Effort!"
        }
    }

    var headerSubtext: String? {
        // Power Walk has its own subtext logic
        if summaryData.walkMode == .interval {
            return powerWalkSubtext
        }

        // Just Walk subtext (existing logic)
        if summaryData.stepsAdded == 0 {
            return "No steps recorded. Try moving your phone next time."
        }

        if summaryData.stepsAdded < 500 {
            return "Every step counts."
        }

        if summaryData.didReachGoalDuringWalk {
            return "You hit your daily goal!"
        }

        if summaryData.wasGoalAlreadyReached {
            return "\(summaryData.stepsAdded.formatted()) bonus steps beyond your goal"
        }

        let progressMade = summaryData.goalProgressAfter - summaryData.goalProgressBefore
        if progressMade > 0 {
            let percentProgress = Int(progressMade * 100)
            return "\(percentProgress)% closer to your goal"
        }

        return "Keep it up!"
    }

    /// Power Walk subtext based on intervals
    private var powerWalkSubtext: String {
        let completed = summaryData.completedIntervals
        let total = summaryData.totalIntervals
        let steps = summaryData.stepsAdded

        // All intervals completed
        if summaryData.completedSuccessfully {
            return "All \(total) intervals · +\(steps.formatted()) steps"
        }

        // No intervals completed
        if completed == 0 {
            if steps == 0 {
                return "No intervals completed"
            } else {
                return "+\(steps.formatted()) steps, but no intervals completed"
            }
        }

        // Partial completion
        return "\(completed) of \(total) intervals · +\(steps.formatted()) steps"
    }

    var encouragementMessage: String {
        let messages: [String]

        if summaryData.walkMode == .classic {
            messages = justWalkEncouragements
        } else if summaryData.completedSuccessfully {
            messages = powerWalkCompletedEncouragements
        } else {
            messages = powerWalkEndedEarlyEncouragements
        }

        // Use a deterministic "random" based on steps to vary messages
        let index = summaryData.stepsAdded % messages.count
        return messages[index]
    }

    var formattedStepsAdded: String {
        "+\(summaryData.stepsAdded.formatted())"
    }

    var formattedDuration: String {
        summaryData.sessionSummary.formattedDuration
    }

    var formattedDistance: String {
        let miles = summaryData.sessionSummary.distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    var intervalsText: String {
        "\(summaryData.completedIntervals) of \(summaryData.totalIntervals)"
    }

    var showEfficiencyStat: Bool {
        summaryData.walkMode == .interval && summaryData.completedSuccessfully
    }

    var showEndedEarlyCard: Bool {
        summaryData.walkMode == .interval && !summaryData.completedSuccessfully
    }

    var showWeeklyPattern: Bool {
        summaryData.walkMode == .interval && powerWalksThisWeek >= 2
    }

    var weeklyPatternText: String {
        "That's \(powerWalksThisWeek) Power Walks this week!"
    }

    /// Whether to show efficiency callout (all intervals completed + meaningful walk)
    var showEfficiencyCallout: Bool {
        guard summaryData.walkMode == .interval else { return false }
        guard summaryData.completedSuccessfully else { return false }
        // Only show for walks with meaningful data (5+ min, 500+ steps)
        return summaryData.sessionSummary.totalDuration >= 300 && summaryData.stepsAdded >= 500
    }

    /// Efficiency callout text
    var efficiencyCalloutText: String? {
        guard showEfficiencyCallout else { return nil }

        let steps = summaryData.stepsAdded
        let minutes = Int(summaryData.sessionSummary.totalDuration / 60)

        // Calculate efficiency vs regular walk
        // Assume regular walk pace: ~100 steps/min
        let regularMinutes = steps / 100
        guard regularMinutes > minutes else { return nil }

        let timeSaved = regularMinutes - minutes
        let percentMore = Int((Double(timeSaved) / Double(regularMinutes)) * 100)

        guard percentMore >= 10 else { return nil } // Only show if meaningful

        return "You walked \(steps.formatted()) steps in \(minutes) min — that's \(percentMore)% more efficient than a regular walk!"
    }

    var showRouteMap: Bool {
        summaryData.routeCoordinates.count > 1
    }

    var conversionCardCTAText: String {
        ConversionTrackingManager.shared.hasUsedFreeTrial
            ? "Unlock Power Walk"
            : "Try Power Walk Free"
    }

    var conversionCardBodyText: String {
        // Don't show confusing projections for short walks
        guard showProjectedStats else {
            return "Build your walking habit with interval training"
        }

        let actualMinutes = Int(summaryData.sessionSummary.totalDuration / 60)
        let powerWalkMinutes = Int(estimatedPowerWalkDuration / 60)

        switch estimatedTimeSaved {
        case 5...9:
            return "Power Walk could save you ~\(estimatedTimeSaved) minutes"
        case 10...15:
            return "That's \(estimatedTimeSaved) minutes you could save with Power Walk"
        case 16...20:
            return "Power Walk would've taken just ~\(powerWalkMinutes) min"
        default:
            if estimatedTimeSaved > 20 {
                return "Imagine finishing in half the time with Power Walk"
            }
            return "Your walk took \(actualMinutes) min. Power Walk could do it in ~\(powerWalkMinutes)."
        }
    }

    // MARK: - Actions

    func dismissConversionCard() {
        conversionCardDismissed = true
        ConversionTrackingManager.shared.recordConversionPromptDismissed()
        ConversionTrackingManager.shared.incrementDismissCount()
    }

    // MARK: - Private Methods

    private func calculateDerivedValues() {
        let tracker = ConversionTrackingManager.shared

        // Calculate time saved
        estimatedTimeSaved = tracker.calculateTimeSaved(
            steps: summaryData.stepsAdded,
            duration: summaryData.sessionSummary.totalDuration
        )

        // Estimate Power Walk duration for this step count
        estimatedPowerWalkDuration = tracker.estimatePowerWalkDuration(
            forSteps: summaryData.stepsAdded
        )

        // Check conversion triggers (only for Just Walk / classic mode)
        if summaryData.walkMode == .classic {
            shouldShowConversionCard = tracker.shouldShowConversionCard(
                timeSavedMinutes: estimatedTimeSaved,
                steps: summaryData.stepsAdded
            )
        }

        // Get weekly Power Walk count
        powerWalksThisWeek = tracker.powerWalksThisWeek
    }

    /// Whether to show projected stats (only for meaningful walks)
    var showProjectedStats: Bool {
        // Only show projections if walk was meaningful (500+ steps, 5+ min)
        summaryData.stepsAdded >= 500 && summaryData.sessionSummary.totalDuration >= 300
    }

    private func trackCompletion() {
        let tracker = ConversionTrackingManager.shared

        if summaryData.walkMode == .classic {
            tracker.recordJustWalkCompletion()
        } else {
            tracker.recordPowerWalkCompletion()
        }
    }
}
