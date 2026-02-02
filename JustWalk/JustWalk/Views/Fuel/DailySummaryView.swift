//
//  DailySummaryView.swift
//  JustWalk
//
//  Daily nutrition summary showing calories and macros for a selected day
//

import SwiftUI

struct DailySummaryView: View {
    let selectedDate: Date
    @ObservedObject private var foodLogManager = FoodLogManager.shared
    @ObservedObject private var goalManager = CalorieGoalManager.shared

    @State private var showGoalSetup = false

    private let calendar = Calendar.current

    // Computed from manager to ensure reactivity
    private var summary: (calories: Int, protein: Int, carbs: Int, fat: Int) {
        foodLogManager.getDailySummary(for: selectedDate)
    }

    // Force view identity based on log count for reliable updates
    private var viewIdentity: String {
        let logs = foodLogManager.getLogs(for: selectedDate)
        let goalId = goalManager.settings?.id.uuidString ?? "none"
        return "\(selectedDate.timeIntervalSince1970)-\(logs.count)-\(summary.calories)-\(goalId)"
    }

    // MARK: - Computed Properties

    private var dateString: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today · \(formattedDate)"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday · \(formattedDate)"
        } else {
            let weekday = selectedDate.formatted(.dateTime.weekday(.wide))
            return "\(weekday) · \(formattedDate)"
        }
    }

    private var formattedDate: String {
        selectedDate.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Goal state for display
    private var goalDisplayState: GoalDisplayState {
        guard let goal = goalManager.dailyGoal else {
            return .noGoal
        }

        let remaining = goal - summary.calories

        if abs(remaining) <= 50 {
            return .onTarget
        } else if remaining > 0 {
            return .underGoal(remaining: remaining)
        } else {
            return .overGoal(amount: abs(remaining))
        }
    }

    /// Progress percentage (capped at 1.0 for display)
    private var progressPercent: Double {
        guard let goal = goalManager.dailyGoal, goal > 0 else { return 0 }
        return min(1.0, Double(summary.calories) / Double(goal))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            // Date header
            Text(dateString)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            // Goal progress section
            goalProgressSection

            // Macro grid (always shown)
            macroGrid
        }
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, JW.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jwCard()
        .id(viewIdentity)
        .sheet(isPresented: $showGoalSetup) {
            CalorieGoalSetupView()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var goalProgressSection: some View {
        switch goalDisplayState {
        case .noGoal:
            // STATE A: No goal set - show link to set goal
            Button {
                showGoalSetup = true
            } label: {
                HStack(spacing: JW.Spacing.xs) {
                    Text("Set a calorie goal")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.accent)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(JW.Color.accent)
                }
            }
            .buttonStyle(.plain)

        case .underGoal(let remaining):
            // STATE B: Under goal - show progress bar with remaining
            goalProgressBar(remaining: remaining, isOver: false)

        case .onTarget:
            // STATE C: On target - show checkmark and tappable goal
            HStack {
                HStack(spacing: JW.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(JW.Color.accent)

                    Text("Right on target")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.accent)
                }

                Spacer()

                // Goal value (tappable to edit)
                Button {
                    showGoalSetup = true
                } label: {
                    HStack(spacing: 2) {
                        Text("\(goalManager.dailyGoal ?? 0) goal")
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.textTertiary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(JW.Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }

        case .overGoal(let amount):
            // STATE D: Over goal
            goalProgressBar(remaining: -amount, isOver: true)
        }
    }

    private func goalProgressBar(remaining: Int, isOver: Bool) -> some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(JW.Color.backgroundTertiary)
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOver ? JW.Color.streak : JW.Color.accent)
                        .frame(width: geo.size.width * progressPercent, height: 8)
                }
            }
            .frame(height: 8)

            // Status text
            HStack {
                if isOver {
                    Text("\(abs(remaining)) over")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.streak)
                } else {
                    Text("\(remaining) left")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()

                // Goal value (tappable to edit)
                Button {
                    showGoalSetup = true
                } label: {
                    HStack(spacing: 2) {
                        Text("\(goalManager.dailyGoal ?? 0) goal")
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.textTertiary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(JW.Color.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var macroGrid: some View {
        HStack(spacing: JW.Spacing.xs) {
            // Only show calories in macro grid if no goal is set
            if !goalManager.hasGoal {
                MacroItem(value: summary.calories, label: "Cal", unit: nil, isHighlighted: true)
            } else {
                MacroItem(value: summary.calories, label: "Eaten", unit: "cal", isHighlighted: true)
            }

            if summary.protein > 0 {
                MacroItem(value: summary.protein, label: "Protein", unit: "g")
            }
            if summary.carbs > 0 {
                MacroItem(value: summary.carbs, label: "Carbs", unit: "g")
            }
            if summary.fat > 0 {
                MacroItem(value: summary.fat, label: "Fat", unit: "g")
            }
        }
    }
}

// MARK: - Goal Display State

private enum GoalDisplayState {
    case noGoal
    case underGoal(remaining: Int)
    case onTarget
    case overGoal(amount: Int)
}

// MARK: - Macro Item

private struct MacroItem: View {
    let value: Int
    let label: String
    let unit: String?
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font(isHighlighted ? JW.Font.title2 : JW.Font.headline)
                    .foregroundStyle(isHighlighted ? JW.Color.accent : JW.Color.textPrimary)

                if let unit = unit {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(JW.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Backward Compatibility

extension DailySummaryView {
    /// Convenience initializer for backward compatibility (summary param is ignored)
    init(selectedDate: Date, summary: (calories: Int, protein: Int, carbs: Int, fat: Int)) {
        self.selectedDate = selectedDate
        // Note: summary param is ignored - we compute directly from FoodLogManager
    }
}

// MARK: - Previews

#Preview("Today") {
    VStack {
        DailySummaryView(selectedDate: Date())
            .padding()

        Spacer()
    }
    .background(JW.Color.backgroundPrimary)
}

#Preview("Past Day") {
    VStack {
        DailySummaryView(
            selectedDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        )
        .padding()

        Spacer()
    }
    .background(JW.Color.backgroundPrimary)
}

#Preview("Yesterday") {
    VStack {
        DailySummaryView(
            selectedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        )
        .padding()

        Spacer()
    }
    .background(JW.Color.backgroundPrimary)
}
