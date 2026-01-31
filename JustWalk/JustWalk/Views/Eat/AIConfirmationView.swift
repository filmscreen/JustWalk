//
//  AIConfirmationView.swift
//  JustWalk
//
//  Confirmation screen for AI-estimated food entries
//

import SwiftUI

struct AIConfirmationView: View {
    let estimate: FoodEstimate
    let mealType: MealType
    let selectedDate: Date
    let onConfirm: (FoodLog) -> Void
    let onAdjust: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JW.Spacing.xl) {
                    // Success indicator
                    successHeader

                    // Estimate card
                    estimateCard

                    // Confidence indicator
                    confidenceIndicator

                    // Notes if any
                    if let notes = estimate.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    // Action buttons
                    actionButtons
                }
                .padding(JW.Spacing.lg)
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Review Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(JW.Color.textSecondary)
                }
            }
            .toolbarBackground(JW.Color.backgroundCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: JW.Spacing.md) {
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }

            Text("AI Estimate Ready")
                .font(JW.Font.title2)
                .foregroundStyle(JW.Color.textPrimary)

            Text("Review and confirm the details below")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding(.top, JW.Spacing.md)
    }

    // MARK: - Estimate Card

    private var estimateCard: some View {
        VStack(spacing: JW.Spacing.lg) {
            // Food name and meal type
            VStack(spacing: JW.Spacing.xs) {
                Text(estimate.name)
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: JW.Spacing.xs) {
                    Text(mealType.icon)
                    Text(mealType.displayName)
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            // Nutrition grid
            HStack(spacing: 0) {
                NutritionItem(value: estimate.calories, label: "Calories", isHighlighted: true)
                NutritionItem(value: estimate.protein, label: "Protein", unit: "g")
                NutritionItem(value: estimate.carbs, label: "Carbs", unit: "g")
                NutritionItem(value: estimate.fat, label: "Fat", unit: "g")
            }

            // Original description
            if !estimate.description.isEmpty {
                VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                    Text("What you described:")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)

                    Text(estimate.description)
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, JW.Spacing.sm)
            }
        }
        .padding(JW.Spacing.lg)
        .jwCard()
    }

    // MARK: - Confidence Indicator

    private var confidenceIndicator: some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: confidenceIcon)
                .font(.system(size: 14))
                .foregroundStyle(confidenceColor)

            Text(estimate.confidence.displayText)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }

    private var confidenceIcon: String {
        switch estimate.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "circle.fill"
        case .low: return "exclamationmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        switch estimate.confidence {
        case .high: return JW.Color.success
        case .medium: return JW.Color.streak
        case .low: return JW.Color.textTertiary
        }
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            Text("Note")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)

            Text(notes)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: JW.Spacing.md) {
            // Primary: Confirm
            Button {
                JustWalkHaptics.success()
                let foodLog = estimate.toFoodLog(date: selectedDate, mealType: mealType)
                onConfirm(foodLog)
                dismiss()
            } label: {
                HStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "checkmark")
                    Text("Looks Right")
                }
                .font(JW.Font.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(JW.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()

            // Secondary: Adjust
            Button {
                JustWalkHaptics.buttonTap()
                onAdjust()
                dismiss()
            } label: {
                Text("Adjust Values")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.accentBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
        .padding(.top, JW.Spacing.md)
    }
}

// MARK: - Nutrition Item

private struct NutritionItem: View {
    let value: Int
    let label: String
    var unit: String? = nil
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

// MARK: - Previews

#Preview("High Confidence") {
    AIConfirmationView(
        estimate: FoodEstimate(
            name: "Chipotle Bowl",
            description: "Chicken burrito bowl with rice, beans, guac, and salsa",
            calories: 920,
            protein: 54,
            carbs: 85,
            fat: 38,
            confidence: .high,
            notes: nil
        ),
        mealType: .lunch,
        selectedDate: Date(),
        onConfirm: { _ in },
        onAdjust: {},
        onCancel: {}
    )
}

#Preview("Low Confidence with Notes") {
    AIConfirmationView(
        estimate: FoodEstimate(
            name: "Breakfast",
            description: "some breakfast food",
            calories: 350,
            protein: 15,
            carbs: 40,
            fat: 12,
            confidence: .low,
            notes: "Estimate based on typical breakfast. Consider adjusting if your meal was larger or smaller."
        ),
        mealType: .breakfast,
        selectedDate: Date(),
        onConfirm: { _ in },
        onAdjust: {},
        onCancel: {}
    )
}
