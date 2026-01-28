import Foundation

struct DayStepData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let steps: Int
    let distance: Double?

    /// Historical goal frozen at time of recording (nil = use default 10k)
    var historicalGoal: Int?

    init(date: Date, steps: Int, distance: Double?, historicalGoal: Int? = nil) {
        self.date = date
        self.steps = steps
        self.distance = distance
        self.historicalGoal = historicalGoal
    }

    static func == (lhs: DayStepData, rhs: DayStepData) -> Bool {
        lhs.date == rhs.date &&
        lhs.steps == rhs.steps &&
        lhs.distance == rhs.distance &&
        lhs.historicalGoal == rhs.historicalGoal
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    /// Effective goal for this day (uses historical goal if set, otherwise 10k default)
    var effectiveGoal: Int {
        historicalGoal ?? 10_000
    }

    /// Whether the goal was met for this specific day using its frozen historical goal
    var isGoalMet: Bool {
        steps >= effectiveGoal
    }

    // MARK: - Step Calculations

    /// Steps remaining to reach goal (0 if goal met)
    var stepsRemaining: Int {
        max(0, effectiveGoal - steps)
    }

    /// Bonus steps beyond goal (0 if goal not met)
    var bonusSteps: Int {
        max(0, steps - effectiveGoal)
    }

    /// Progress toward goal (0.0 to 1.0+)
    var progress: Double {
        guard effectiveGoal > 0 else { return 0 }
        return Double(steps) / Double(effectiveGoal)
    }

    // MARK: - Formatted Output

    /// Steps formatted with commas (e.g., "8,200")
    var formattedSteps: String {
        FormatUtils.formatSteps(steps)
    }

    /// Steps formatted abbreviated (e.g., "8.2k")
    var formattedStepsAbbreviated: String {
        FormatUtils.formatStepsAbbreviated(steps)
    }

    /// Remaining steps formatted (e.g., "1,800 to go" or "Goal hit!")
    var formattedRemaining: String {
        FormatUtils.formatRemaining(stepsRemaining)
    }

    /// Bonus steps formatted (e.g., "+247 bonus steps")
    var formattedBonus: String {
        FormatUtils.formatBonus(bonusSteps)
    }

    /// Distance formatted in miles (e.g., "3.8 mi")
    var formattedDistanceMiles: String? {
        guard let distance = distance, distance > 0 else { return nil }
        let miles = distance * 0.000621371
        return FormatUtils.formatDistanceMiles(miles)
    }
}
