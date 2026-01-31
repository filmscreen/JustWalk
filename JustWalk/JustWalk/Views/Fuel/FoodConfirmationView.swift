//
//  FoodConfirmationView.swift
//  JustWalk
//
//  Confirmation screen for AI-estimated food with inline editable fields
//

import SwiftUI

struct FoodConfirmationView: View {
    let originalEstimate: FoodEstimate
    let selectedDate: Date
    let onSave: (FoodLog) -> Void
    let onCancel: () -> Void

    // Editable state
    @State private var name: String
    @State private var mealType: MealType
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, calories, protein, carbs, fat
    }

    // Track if any field was edited
    private var wasEdited: Bool {
        name != originalEstimate.name ||
        (Int(caloriesText) ?? 0) != originalEstimate.calories ||
        (Int(proteinText) ?? 0) != originalEstimate.protein ||
        (Int(carbsText) ?? 0) != originalEstimate.carbs ||
        (Int(fatText) ?? 0) != originalEstimate.fat ||
        mealType != .unspecified // If meal type was changed from default
    }

    private var entrySource: EntrySource {
        wasEdited ? .aiAdjusted : .ai
    }

    // Validation
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Int(caloriesText) ?? -1) >= 0
    }

    init(
        originalEstimate: FoodEstimate,
        mealType: MealType,
        selectedDate: Date,
        onSave: @escaping (FoodLog) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalEstimate = originalEstimate
        self.selectedDate = selectedDate
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize editable state from estimate
        _name = State(initialValue: originalEstimate.name)
        _mealType = State(initialValue: mealType)
        _caloriesText = State(initialValue: String(originalEstimate.calories))
        _proteinText = State(initialValue: String(originalEstimate.protein))
        _carbsText = State(initialValue: String(originalEstimate.carbs))
        _fatText = State(initialValue: String(originalEstimate.fat))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JW.Spacing.xl) {
                    // AI badge
                    aiBadge

                    // Editable fields
                    editableFieldsSection

                    // Original description
                    originalDescriptionSection

                    // Confidence info
                    if originalEstimate.confidence != .high || originalEstimate.notes != nil {
                        confidenceSection
                    }

                    // Save button
                    saveButton
                }
                .padding(JW.Spacing.lg)
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Review Entry")
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

    // MARK: - AI Badge

    private var aiBadge: some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
            Text("AI Estimate")
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

    // MARK: - Editable Fields Section

    private var editableFieldsSection: some View {
        VStack(spacing: JW.Spacing.md) {
            // Name field
            EditableTextField(
                label: "Name",
                text: $name,
                placeholder: "Food name"
            )
            .focused($focusedField, equals: .name)

            // Meal type selector
            mealTypeSelector

            // Nutrition fields in grid
            nutritionGrid
        }
        .padding(JW.Spacing.lg)
        .jwCard()
    }

    private var mealTypeSelector: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            Text("Meal")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: JW.Spacing.sm) {
                    ForEach(MealType.allCases.filter { $0 != .unspecified }, id: \.self) { type in
                        MealChip(
                            mealType: type,
                            isSelected: mealType == type
                        ) {
                            mealType = type
                            JustWalkHaptics.selectionChanged()
                        }
                    }
                }
            }
        }
    }

    private var nutritionGrid: some View {
        VStack(spacing: JW.Spacing.md) {
            // Calories (prominent)
            EditableNumberField(
                label: "Calories",
                text: $caloriesText,
                isHighlighted: true
            )
            .focused($focusedField, equals: .calories)

            // Macros row
            HStack(spacing: JW.Spacing.md) {
                EditableNumberField(
                    label: "Protein",
                    text: $proteinText,
                    suffix: "g"
                )
                .focused($focusedField, equals: .protein)

                EditableNumberField(
                    label: "Carbs",
                    text: $carbsText,
                    suffix: "g"
                )
                .focused($focusedField, equals: .carbs)

                EditableNumberField(
                    label: "Fat",
                    text: $fatText,
                    suffix: "g"
                )
                .focused($focusedField, equals: .fat)
            }
        }
    }

    // MARK: - Original Description

    private var originalDescriptionSection: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            Text("What you described")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)

            Text(originalEstimate.description)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(JW.Spacing.lg)
        .jwCard()
    }

    // MARK: - Confidence Section

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: confidenceIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(confidenceColor)

                Text(originalEstimate.confidence.displayText)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            if let notes = originalEstimate.notes, !notes.isEmpty {
                Text(notes)
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
    }

    private var confidenceIcon: String {
        switch originalEstimate.confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "circle.fill"
        case .low: return "exclamationmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        switch originalEstimate.confidence {
        case .high: return JW.Color.success
        case .medium: return JW.Color.streak
        case .low: return JW.Color.textTertiary
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: JW.Spacing.sm) {
            Button {
                saveEntry()
            } label: {
                HStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "checkmark")
                    Text("Save Entry")
                }
                .font(JW.Font.headline)
                .foregroundStyle(isValid ? .black : JW.Color.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isValid ? JW.Color.accent : JW.Color.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .disabled(!isValid)
            .buttonPressEffect()

            if wasEdited {
                Text("Values adjusted from AI estimate")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }
        }
        .padding(.top, JW.Spacing.md)
    }

    // MARK: - Actions

    private func saveEntry() {
        guard isValid else { return }

        let foodLog = FoodLog(
            date: selectedDate,
            mealType: mealType,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            entryDescription: originalEstimate.description,
            calories: Int(caloriesText) ?? 0,
            protein: Int(proteinText) ?? 0,
            carbs: Int(carbsText) ?? 0,
            fat: Int(fatText) ?? 0,
            source: entrySource
        )

        JustWalkHaptics.success()
        onSave(foodLog)
        dismiss()
    }
}

// MARK: - Editable Text Field

private struct EditableTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            TextField(placeholder, text: $text)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)
                .padding(JW.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: JW.Radius.md)
                        .fill(JW.Color.backgroundTertiary)
                )
        }
    }
}

// MARK: - Editable Number Field

private struct EditableNumberField: View {
    let label: String
    @Binding var text: String
    var suffix: String? = nil
    var isHighlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            HStack(spacing: JW.Spacing.xs) {
                TextField("0", text: $text)
                    .font(isHighlighted ? JW.Font.title2 : JW.Font.headline)
                    .foregroundStyle(isHighlighted ? JW.Color.accent : JW.Color.textPrimary)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(suffix != nil ? .trailing : .leading)

                if let suffix = suffix {
                    Text(suffix)
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(JW.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .fill(JW.Color.backgroundTertiary)
            )
        }
    }
}

// MARK: - Meal Chip

private struct MealChip: View {
    let mealType: MealType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: JW.Spacing.xs) {
                Text(mealType.icon)
                    .font(.system(size: 14))
                Text(mealType.displayName)
                    .font(JW.Font.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? JW.Color.backgroundPrimary : JW.Color.textSecondary)
            .padding(.horizontal, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? JW.Color.accent : JW.Color.backgroundTertiary)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("High Confidence") {
    FoodConfirmationView(
        originalEstimate: FoodEstimate(
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
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Low Confidence with Notes") {
    FoodConfirmationView(
        originalEstimate: FoodEstimate(
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
        onSave: { _ in },
        onCancel: {}
    )
}
