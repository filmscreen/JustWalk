//
//  FoodLogListView.swift
//  JustWalk
//
//  Displays food entries grouped by meal type for a selected day
//

import SwiftUI

struct FoodLogListView: View {
    let logsByMeal: [MealType: [FoodLog]]
    let onEntryTapped: (FoodLog) -> Void
    let onAddToMeal: (MealType) -> Void
    let onDeleteEntry: ((FoodLog) -> Void)?
    let isToday: Bool
    let onTryExampleTapped: (() -> Void)?

    // State for delete confirmation
    @State private var entryToDelete: FoodLog?
    @State private var showDeleteConfirmation = false

    // Define display order for meal types (includes unspecified to catch any orphaned entries)
    private let mealOrder: [MealType] = [.breakfast, .lunch, .dinner, .snack, .unspecified]

    init(
        logsByMeal: [MealType: [FoodLog]],
        onEntryTapped: @escaping (FoodLog) -> Void,
        onAddToMeal: @escaping (MealType) -> Void,
        onDeleteEntry: ((FoodLog) -> Void)? = nil,
        isToday: Bool = true,
        onTryExampleTapped: (() -> Void)? = nil
    ) {
        self.logsByMeal = logsByMeal
        self.onEntryTapped = onEntryTapped
        self.onAddToMeal = onAddToMeal
        self.onDeleteEntry = onDeleteEntry
        self.isToday = isToday
        self.onTryExampleTapped = onTryExampleTapped
    }

    private var hasAnyEntries: Bool {
        !logsByMeal.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: JW.Spacing.sm) {
            if hasAnyEntries {
                // Section header for log items
                HStack {
                    Text("TODAY'S LOG")
                        .font(JW.Font.caption.bold())
                        .foregroundStyle(JW.Color.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                }
                .padding(.top, JW.Spacing.sm)

                // Show meal groups with entries
                ForEach(mealOrder, id: \.self) { mealType in
                    if let entries = logsByMeal[mealType], !entries.isEmpty {
                        MealGroupView(
                            mealType: mealType,
                            entries: entries,
                            onEntryTapped: onEntryTapped,
                            onAddTapped: { onAddToMeal(mealType) },
                            onDeleteRequested: onDeleteEntry != nil ? { entry in
                                entryToDelete = entry
                                showDeleteConfirmation = true
                            } : nil
                        )
                    }
                }
            } else {
                // Empty state
                emptyState
            }
        }
        .confirmationDialog(
            "Delete Entry?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: entryToDelete
        ) { entry in
            Button("Delete", role: .destructive) {
                JustWalkHaptics.buttonTap()
                onDeleteEntry?(entry)
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: { entry in
            Text("\"\(entry.name)\" – \(entry.calories) cal\n\nThis will update your daily totals.")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: JW.Spacing.md) {
            Text("No meals logged yet")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textSecondary)

            Text("Just describe what you ate —\nwe handle the rest.")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textTertiary)
                .multilineTextAlignment(.center)

            // "Try it" example - only show for today
            if isToday, let onTryExample = onTryExampleTapped {
                Button {
                    JustWalkHaptics.buttonTap()
                    onTryExample()
                } label: {
                    HStack(spacing: JW.Spacing.xs) {
                        Text("Try it:")
                            .foregroundStyle(JW.Color.textTertiary)
                        Text("\"2 eggs and toast\"")
                            .foregroundStyle(JW.Color.accent)
                    }
                    .font(JW.Font.subheadline)
                }
                .buttonStyle(.plain)
                .padding(.top, JW.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, JW.Spacing.xxl)
    }
}

// MARK: - Meal Group View

private struct MealGroupView: View {
    let mealType: MealType
    let entries: [FoodLog]
    let onEntryTapped: (FoodLog) -> Void
    let onAddTapped: () -> Void
    let onDeleteRequested: ((FoodLog) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Meal header with accent bar
            HStack(spacing: 0) {
                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(JW.Color.accent)
                    .frame(width: 3)
                    .padding(.vertical, 4)

                mealHeader
                    .padding(.leading, JW.Spacing.sm)
            }
            .padding(.horizontal, JW.Spacing.md)
            .padding(.top, JW.Spacing.md)
            .padding(.bottom, JW.Spacing.xs)

            // Entry rows - indented to show hierarchy
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    FoodEntryRow(
                        entry: entry,
                        onTap: { onEntryTapped(entry) },
                        onDelete: onDeleteRequested != nil ? { onDeleteRequested?(entry) } : nil
                    )

                    // Divider between entries (not after last)
                    if entry.id != entries.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.leading, JW.Spacing.xl)
                    }
                }
            }

            // Add to meal button
            addButton
                .padding(.leading, JW.Spacing.xl)
                .padding(.trailing, JW.Spacing.md)
                .padding(.top, JW.Spacing.xs)
                .padding(.bottom, JW.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard.opacity(0.5))
        )
    }

    private var mealHeader: some View {
        HStack(spacing: JW.Spacing.sm) {
            Text(mealType.icon)
                .font(.system(size: 20))

            Text(mealType.displayName)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            // Meal total calories (with ~ if any items are AI-estimated)
            Text(mealCaloriesText)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }

    private var addButton: some View {
        Button(action: {
            JustWalkHaptics.buttonTap()
            onAddTapped()
        }) {
            HStack(spacing: JW.Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add to \(mealType.displayName.lowercased())")
                    .font(JW.Font.subheadline)
            }
            .foregroundStyle(JW.Color.accentBlue)
        }
    }

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    /// True if any entry in this meal is AI-estimated
    private var hasAIEstimates: Bool {
        entries.contains { $0.source == .ai || $0.source == .aiAdjusted }
    }

    /// Formatted calorie text for the meal
    private var mealCaloriesText: String {
        return "\(totalCalories) cal"
    }
}

// MARK: - Food Entry Row

private struct FoodEntryRow: View {
    let entry: FoodLog
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: {
            JustWalkHaptics.buttonTap()
            onTap()
        }) {
            HStack(spacing: JW.Spacing.md) {
                // Entry info
                VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                    Text(entry.name)
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: JW.Spacing.sm) {
                        Text(caloriesText)
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.textSecondary)

                        if entry.protein > 0 {
                            Text("·")
                                .font(JW.Font.caption)
                                .foregroundStyle(JW.Color.textTertiary)

                            Text("\(entry.protein)g protein")
                                .font(JW.Font.caption)
                                .foregroundStyle(JW.Color.textSecondary)
                        }
                    }
                }

                Spacer()

                // Disclosure indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(JW.Color.textTertiary)
            }
            .padding(.leading, JW.Spacing.xl)
            .padding(.trailing, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var caloriesText: String {
        return "\(entry.calories) cal"
    }
}

// MARK: - Previews

#Preview("With Entries") {
    let mockLogs: [MealType: [FoodLog]] = [
        .breakfast: [
            FoodLog(
                mealType: .breakfast,
                name: "Oatmeal with berries",
                calories: 320,
                protein: 12,
                source: .manual
            ),
            FoodLog(
                mealType: .breakfast,
                name: "Coffee with oat milk",
                calories: 45,
                protein: 1,
                source: .ai
            )
        ],
        .lunch: [
            FoodLog(
                mealType: .lunch,
                name: "Chipotle bowl",
                entryDescription: "Chicken, rice, black beans, guac",
                calories: 920,
                protein: 54,
                source: .ai
            )
        ],
        .snack: [
            FoodLog(
                mealType: .snack,
                name: "Apple with peanut butter",
                calories: 280,
                protein: 8,
                source: .manual
            )
        ]
    ]

    ScrollView {
        FoodLogListView(
            logsByMeal: mockLogs,
            onEntryTapped: { log in print("Tapped: \(log.name)") },
            onAddToMeal: { meal in print("Add to: \(meal.displayName)") }
        )
        .padding()
    }
    .background(JW.Color.backgroundPrimary)
}

#Preview("Empty State") {
    ScrollView {
        FoodLogListView(
            logsByMeal: [:],
            onEntryTapped: { _ in },
            onAddToMeal: { _ in }
        )
        .padding()
    }
    .background(JW.Color.backgroundPrimary)
}

#Preview("Single Meal") {
    let mockLogs: [MealType: [FoodLog]] = [
        .dinner: [
            FoodLog(
                mealType: .dinner,
                name: "Grilled salmon",
                calories: 450,
                protein: 42,
                source: .ai
            ),
            FoodLog(
                mealType: .dinner,
                name: "Roasted vegetables",
                calories: 180,
                protein: 5,
                source: .manual
            ),
            FoodLog(
                mealType: .dinner,
                name: "Brown rice",
                calories: 220,
                protein: 5,
                source: .manual
            )
        ]
    ]

    ScrollView {
        FoodLogListView(
            logsByMeal: mockLogs,
            onEntryTapped: { _ in },
            onAddToMeal: { _ in }
        )
        .padding()
    }
    .background(JW.Color.backgroundPrimary)
}
