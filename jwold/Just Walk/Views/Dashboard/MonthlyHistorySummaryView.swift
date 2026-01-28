//
//  MonthlyHistorySummaryView.swift
//  Just Walk
//
//  Simple read-only monthly summary showing days completed per month.
//

import SwiftUI

struct MonthlyHistorySummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dataViewModel = DataViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(monthlySummaries.enumerated()), id: \.element.month) { index, summary in
                        monthRow(summary)

                        // Divider between months (not after last)
                        if index < monthlySummaries.count - 1 {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 0.5)
                                .padding(.horizontal, 16)  // Align with row content
                        }
                    }
                }
                .padding(.vertical, 16)  // Vertical padding only - rows handle horizontal
                .background(Color(.secondarySystemGroupedBackground))  // Card background
                .clipShape(RoundedRectangle(cornerRadius: 12))  // 12pt radius
                .padding(.horizontal, 16)  // 16pt outside card
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))  // Screen background
            .navigationTitle("Full History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            await dataViewModel.loadData()
        }
    }

    // MARK: - Month Row

    @ViewBuilder
    private func monthRow(_ summary: MonthlySummary) -> some View {
        HStack(alignment: .top, spacing: 12) {  // Explicit 12pt spacing
            // Left column - month info
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.monthName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                miniStreakDots(summary.dailyResults)
                    .padding(.top, 4)

                Text("\(summary.daysCompleted) of \(summary.totalDays) days")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer(minLength: 8)  // CRITICAL: Minimum gap prevents squeezing

            // Right column - percentage (fixed width for alignment)
            if summary.percentage > 0 {
                Text("\(summary.percentage)%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 70, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "AEAEB2"))
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)  // CRITICAL: Each row has its own padding
        .padding(.vertical, 12)    // Consistent vertical spacing
    }

    // MARK: - Monthly Summary Model

    private struct MonthlySummary {
        let month: Date
        let monthName: String
        let daysCompleted: Int
        let totalDays: Int
        let dailyResults: [Bool]  // Goal met status for each day (chronological order)

        var percentage: Int {
            totalDays > 0 ? (daysCompleted * 100) / totalDays : 0
        }
    }

    // MARK: - Computed Summaries

    private var monthlySummaries: [MonthlySummary] {
        let calendar = Calendar.current
        var summaries: [MonthlySummary] = []

        // Group yearData by month
        let grouped = Dictionary(grouping: dataViewModel.yearData) { day in
            startOfMonth(for: day.date, calendar: calendar)
        }

        // Create summaries for each month
        for (month, days) in grouped.sorted(by: { $0.key > $1.key }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"

            // Sort days chronologically and extract goal status
            let sortedDays = days.sorted { $0.date < $1.date }
            let dailyResults = sortedDays.map { $0.isGoalMet }

            let daysCompleted = days.filter { $0.isGoalMet }.count
            let totalDays = days.count

            summaries.append(MonthlySummary(
                month: month,
                monthName: formatter.string(from: month),
                daysCompleted: daysCompleted,
                totalDays: totalDays,
                dailyResults: dailyResults
            ))
        }

        return summaries
    }

    // MARK: - Mini Streak Dots (Wrapping Flow Layout)

    @ViewBuilder
    private func miniStreakDots(_ results: [Bool]) -> some View {
        // Use LazyVGrid to wrap dots to multiple lines
        let columns = Array(repeating: GridItem(.fixed(6), spacing: 4), count: 16)  // 16 dots per row max

        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(results.indices, id: \.self) { index in
                Circle()
                    .fill(results[index] ? Color(hex: "00C7BE") : Color(.systemGray4))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helper

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Preview

#Preview {
    MonthlyHistorySummaryView()
}
