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

    // State for delete confirmation
    @State private var entryToDelete: FoodLog?
    @State private var showDeleteConfirmation = false

    // Define display order for meal types
    private let mealOrder: [MealType] = [.breakfast, .lunch, .dinner, .snack]

    init(
        logsByMeal: [MealType: [FoodLog]],
        onEntryTapped: @escaping (FoodLog) -> Void,
        onAddToMeal: @escaping (MealType) -> Void,
        onDeleteEntry: ((FoodLog) -> Void)? = nil
    ) {
        self.logsByMeal = logsByMeal
        self.onEntryTapped = onEntryTapped
        self.onAddToMeal = onAddToMeal
        self.onDeleteEntry = onDeleteEntry
    }

    private var hasAnyEntries: Bool {
        !logsByMeal.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: JW.Spacing.md) {
            if hasAnyEntries {
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

            Text("Use the input above to log what you ate")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textTertiary)
                .multilineTextAlignment(.center)
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
            // Meal header
            mealHeader
                .padding(.horizontal, JW.Spacing.lg)
                .padding(.top, JW.Spacing.lg)
                .padding(.bottom, JW.Spacing.sm)

            // Entry rows
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
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, JW.Spacing.lg)
                    }
                }
            }

            // Add to meal button
            addButton
                .padding(.horizontal, JW.Spacing.lg)
                .padding(.top, JW.Spacing.sm)
                .padding(.bottom, JW.Spacing.lg)
        }
        .jwCard()
    }

    private var mealHeader: some View {
        HStack(spacing: JW.Spacing.sm) {
            Text(mealType.icon)
                .font(.system(size: 20))

            Text(mealType.displayName)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            // Meal total calories
            Text("\(totalCalories) cal")
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
            .padding(.horizontal, JW.Spacing.lg)
            .padding(.vertical, JW.Spacing.md)
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
        // Show ~ for AI-estimated entries
        let prefix = entry.source == .ai ? "~" : ""
        return "\(prefix)\(entry.calories) cal"
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
