//
//  RecalculateComparisonView.swift
//  JustWalk
//
//  Shows before/after comparison when recalculating AI estimate
//

import SwiftUI

struct RecalculateComparisonView: View {
    let currentEntry: FoodLog
    let onApplyNewEstimate: (FoodLog) -> Void
    let onKeepCurrent: () -> Void

    @State private var phase: Phase = .loading
    @State private var newEstimate: FoodEstimate?

    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case loading
        case comparison
        case error(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    loadingView

                case .comparison:
                    if let estimate = newEstimate {
                        comparisonView(newEstimate: estimate)
                    }

                case .error(let message):
                    errorView(message: message)
                }
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Recalculate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(JW.Color.textSecondary)
                }
            }
            .toolbarBackground(JW.Color.backgroundCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            await recalculate()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: JW.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
                    .symbolEffect(.pulse)
            }

            Text("Recalculating...")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Text("Getting fresh AI estimate")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Comparison View

    private func comparisonView(newEstimate: FoodEstimate) -> some View {
        ScrollView {
            VStack(spacing: JW.Spacing.xl) {
                // Header
                comparisonHeader

                // Food name
                VStack(spacing: JW.Spacing.sm) {
                    Text(currentEntry.name)
                        .font(JW.Font.title2)
                        .foregroundStyle(JW.Color.textPrimary)

                    if !currentEntry.entryDescription.isEmpty {
                        Text(currentEntry.entryDescription)
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // Comparison table
                comparisonTable(newEstimate: newEstimate)

                // Confidence indicator
                if newEstimate.confidence != .high {
                    confidenceNote(newEstimate: newEstimate)
                }

                // Action buttons
                actionButtons(newEstimate: newEstimate)
            }
            .padding(JW.Spacing.lg)
        }
    }

    private var comparisonHeader: some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
            Text("New AI Estimate Ready")
                .font(JW.Font.caption)
        }
        .foregroundStyle(JW.Color.accent)
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, JW.Spacing.xs)
        .background(
            Capsule()
                .fill(JW.Color.accent.opacity(0.15))
        )
    }

    private func comparisonTable(newEstimate: FoodEstimate) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Current")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
                    .frame(width: 80)
                Text("New")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.accent)
                    .frame(width: 80)
            }
            .padding(.horizontal, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.sm)

            Divider()
                .background(Color.white.opacity(0.1))

            // Calories row (highlighted)
            comparisonRow(
                label: "Calories",
                currentValue: currentEntry.calories,
                newValue: newEstimate.calories,
                isHighlighted: true
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // Protein row
            comparisonRow(
                label: "Protein",
                currentValue: currentEntry.protein,
                newValue: newEstimate.protein,
                suffix: "g"
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // Carbs row
            comparisonRow(
                label: "Carbs",
                currentValue: currentEntry.carbs,
                newValue: newEstimate.carbs,
                suffix: "g"
            )

            Divider()
                .background(Color.white.opacity(0.1))

            // Fat row
            comparisonRow(
                label: "Fat",
                currentValue: currentEntry.fat,
                newValue: newEstimate.fat,
                suffix: "g"
            )
        }
        .jwCard()
    }

    private func comparisonRow(
        label: String,
        currentValue: Int,
        newValue: Int,
        suffix: String? = nil,
        isHighlighted: Bool = false
    ) -> some View {
        let difference = newValue - currentValue
        let hasDifference = difference != 0

        return HStack {
            Text(label)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Current value
            HStack(spacing: 2) {
                Text("\(currentValue)")
                    .font(isHighlighted ? JW.Font.headline : JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                if let suffix = suffix {
                    Text(suffix)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .frame(width: 80)

            // New value with difference indicator
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text("\(newValue)")
                        .font(isHighlighted ? JW.Font.headline : JW.Font.subheadline)
                        .foregroundStyle(isHighlighted ? JW.Color.accent : JW.Color.textPrimary)
                    if let suffix = suffix {
                        Text(suffix)
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.textTertiary)
                    }
                }

                if hasDifference {
                    Text(difference > 0 ? "+\(difference)" : "\(difference)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(difference > 0 ? JW.Color.streak : JW.Color.accentBlue)
                }
            }
            .frame(width: 80)
        }
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, JW.Spacing.md)
    }

    private func confidenceNote(newEstimate: FoodEstimate) -> some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: newEstimate.confidence == .low ? "exclamationmark.circle.fill" : "circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(newEstimate.confidence == .low ? JW.Color.textTertiary : JW.Color.streak)

            Text(newEstimate.confidence.displayText)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }

    private func actionButtons(newEstimate: FoodEstimate) -> some View {
        VStack(spacing: JW.Spacing.md) {
            // Apply new estimate
            Button {
                JustWalkHaptics.success()
                let updatedEntry = createUpdatedEntry(from: newEstimate)
                onApplyNewEstimate(updatedEntry)
                dismiss()
            } label: {
                HStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "checkmark")
                    Text("Apply New Estimate")
                }
                .font(JW.Font.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(JW.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()

            // Keep current
            Button {
                JustWalkHaptics.buttonTap()
                onKeepCurrent()
                dismiss()
            } label: {
                Text("Keep Current Values")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.accentBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
        }
        .padding(.top, JW.Spacing.md)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: JW.Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(JW.Color.danger.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(JW.Color.danger)
            }

            Text("Couldn't Recalculate")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Text(message)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, JW.Spacing.xl)

            VStack(spacing: JW.Spacing.md) {
                Button {
                    phase = .loading
                    Task {
                        await recalculate()
                    }
                } label: {
                    Text("Try Again")
                        .font(JW.Font.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(JW.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.top, JW.Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func recalculate() async {
        // Use the description if available, otherwise use name
        let description = currentEntry.entryDescription.isEmpty
            ? currentEntry.name
            : currentEntry.entryDescription

        // Use fresh estimation - treat edited description as new item
        let result = await GeminiService.shared.estimateFoodWithResult(description)

        switch result {
        case .success(let estimate):
            newEstimate = estimate
            phase = .comparison

        case .retryable(let error):
            phase = .error(error.userMessage)

        case .needsManualEntry(let error):
            phase = .error(error.userMessage)
        }
    }

    private func createUpdatedEntry(from estimate: FoodEstimate) -> FoodLog {
        FoodLog(
            id: currentEntry.id,
            logID: currentEntry.logID,
            date: currentEntry.date,
            mealType: currentEntry.mealType,
            name: estimate.name,
            entryDescription: currentEntry.entryDescription,
            calories: estimate.calories,
            protein: estimate.protein,
            carbs: estimate.carbs,
            fat: estimate.fat,
            source: .aiAdjusted,
            createdAt: currentEntry.createdAt,
            modifiedAt: Date()
        )
    }
}

// MARK: - Previews

#Preview("Comparison") {
    RecalculateComparisonView(
        currentEntry: FoodLog(
            date: Date(),
            mealType: .lunch,
            name: "Chipotle Bowl",
            entryDescription: "Chicken burrito bowl with rice, beans, guac",
            calories: 800,
            protein: 45,
            carbs: 70,
            fat: 35,
            source: .ai
        ),
        onApplyNewEstimate: { _ in },
        onKeepCurrent: {}
    )
}

#Preview("Loading") {
    RecalculateComparisonView(
        currentEntry: FoodLog(
            date: Date(),
            mealType: .lunch,
            name: "Lunch",
            entryDescription: "Some food",
            calories: 500,
            protein: 20,
            carbs: 50,
            fat: 20,
            source: .manual
        ),
        onApplyNewEstimate: { _ in },
        onKeepCurrent: {}
    )
}
