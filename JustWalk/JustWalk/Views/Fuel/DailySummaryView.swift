//
//  DailySummaryView.swift
//  JustWalk
//
//  Daily nutrition summary showing calories and macros for a selected day
//

import SwiftUI

struct DailySummaryView: View {
    let selectedDate: Date
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int

    private let calendar = Calendar.current

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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.md) {
            // Date header
            Text(dateString)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            // Macro grid
            HStack(spacing: JW.Spacing.sm) {
                MacroItem(value: calories, label: "Calories", unit: nil, isHighlighted: true)
                MacroItem(value: protein, label: "Protein", unit: "g")
                MacroItem(value: carbs, label: "Carbs", unit: "g")
                MacroItem(value: fat, label: "Fat", unit: "g")
            }
        }
        .padding(JW.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jwCard()
    }
}

// MARK: - Macro Item

private struct MacroItem: View {
    let value: Int
    let label: String
    let unit: String?
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: JW.Spacing.xs) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(isHighlighted ? JW.Font.title1 : JW.Font.title2)
                    .foregroundStyle(isHighlighted ? JW.Color.accent : JW.Color.textPrimary)

                if let unit = unit {
                    Text(unit)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }

            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Convenience Initializer

extension DailySummaryView {
    /// Initialize with a summary tuple from FoodLogManager
    init(selectedDate: Date, summary: (calories: Int, protein: Int, carbs: Int, fat: Int)) {
        self.selectedDate = selectedDate
        self.calories = summary.calories
        self.protein = summary.protein
        self.carbs = summary.carbs
        self.fat = summary.fat
    }
}

// MARK: - Previews

#Preview("Today with Data") {
    VStack {
        DailySummaryView(
            selectedDate: Date(),
            calories: 1850,
            protein: 120,
            carbs: 180,
            fat: 65
        )
        .padding()

        Spacer()
    }
    .background(JW.Color.backgroundPrimary)
}

#Preview("Past Day with Data") {
    VStack {
        DailySummaryView(
            selectedDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            calories: 2100,
            protein: 95,
            carbs: 220,
            fat: 80
        )
        .padding()

        Spacer()
    }
    .background(JW.Color.backgroundPrimary)
}

#Preview("Empty Day") {
    VStack {
        DailySummaryView(
            selectedDate: Date(),
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0
        )
        .padding()

        Spacer()
    }
    .background(JW.Color.backgroundPrimary)
}

#Preview("Yesterday") {
    VStack {
        DailySummaryView(
            selectedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            calories: 1650,
            protein: 85,
            carbs: 150,
            fat: 55
        )
        .padding()

        Spacer()
    }
    .background(JW.Color.backgroundPrimary)
}
