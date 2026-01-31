//
//  EditFoodEntryView.swift
//  JustWalk
//
//  Edit screen for modifying existing food log entries
//

import SwiftUI

struct EditFoodEntryView: View {
    let originalEntry: FoodLog
    let onSave: (FoodLog) -> Void
    let onDelete: (FoodLog) -> Void
    let onRecalculate: (FoodLog) -> Void

    // Editable state
    @State private var name: String
    @State private var entryDescription: String
    @State private var mealType: MealType
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String

    @State private var showDeleteConfirmation = false

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, description, calories, protein, carbs, fat
    }

    // Track if any field was edited
    private var wasEdited: Bool {
        name != originalEntry.name ||
        entryDescription != originalEntry.entryDescription ||
        mealType != originalEntry.mealType ||
        (Int(caloriesText) ?? 0) != originalEntry.calories ||
        (Int(proteinText) ?? 0) != originalEntry.protein ||
        (Int(carbsText) ?? 0) != originalEntry.carbs ||
        (Int(fatText) ?? 0) != originalEntry.fat
    }

    // Validation
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Int(caloriesText) ?? -1) >= 0
    }

    init(
        entry: FoodLog,
        onSave: @escaping (FoodLog) -> Void,
        onDelete: @escaping (FoodLog) -> Void,
        onRecalculate: @escaping (FoodLog) -> Void
    ) {
        self.originalEntry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        self.onRecalculate = onRecalculate

        // Initialize editable state from entry
        _name = State(initialValue: entry.name)
        _entryDescription = State(initialValue: entry.entryDescription)
        _mealType = State(initialValue: entry.mealType)
        _caloriesText = State(initialValue: String(entry.calories))
        _proteinText = State(initialValue: String(entry.protein))
        _carbsText = State(initialValue: String(entry.carbs))
        _fatText = State(initialValue: String(entry.fat))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JW.Spacing.xl) {
                    // Source badge
                    sourceBadge

                    // Editable fields
                    editableFieldsSection

                    // Recalculate button
                    if !entryDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        recalculateButton
                    }

                    // Save button
                    saveButton

                    // Delete button
                    deleteButton
                }
                .padding(JW.Spacing.lg)
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Edit Entry")
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
            .confirmationDialog(
                "Delete Entry?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    JustWalkHaptics.buttonTap()
                    onDelete(originalEntry)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\"\(originalEntry.name)\" – \(originalEntry.calories) cal\n\nThis will update your daily totals.")
            }
        }
    }

    // MARK: - Source Badge

    private var sourceBadge: some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: sourceIcon)
                .font(.system(size: 14))
            Text(sourceText)
                .font(JW.Font.caption)
        }
        .foregroundStyle(sourceColor)
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, JW.Spacing.xs)
        .background(
            Capsule()
                .fill(sourceColor.opacity(0.15))
        )
    }

    private var sourceIcon: String {
        switch originalEntry.source {
        case .ai: return "sparkles"
        case .aiAdjusted: return "sparkles"
        case .manual: return "pencil"
        }
    }

    private var sourceText: String {
        switch originalEntry.source {
        case .ai: return "AI Estimate"
        case .aiAdjusted: return "AI Adjusted"
        case .manual: return "Manual Entry"
        }
    }

    private var sourceColor: Color {
        switch originalEntry.source {
        case .ai, .aiAdjusted: return JW.Color.accent
        case .manual: return JW.Color.accentBlue
        }
    }

    // MARK: - Editable Fields Section

    private var editableFieldsSection: some View {
        VStack(spacing: JW.Spacing.md) {
            // Name field
            EditableEntryTextField(
                label: "Name",
                text: $name,
                placeholder: "Food name"
            )
            .focused($focusedField, equals: .name)

            // Description field
            EditableEntryTextField(
                label: "Description",
                text: $entryDescription,
                placeholder: "What you ate (optional)",
                isMultiline: true
            )
            .focused($focusedField, equals: .description)

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
                        EditMealChip(
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
            EditableEntryNumberField(
                label: "Calories",
                text: $caloriesText,
                isHighlighted: true
            )
            .focused($focusedField, equals: .calories)

            // Macros row
            HStack(spacing: JW.Spacing.md) {
                EditableEntryNumberField(
                    label: "Protein",
                    text: $proteinText,
                    suffix: "g"
                )
                .focused($focusedField, equals: .protein)

                EditableEntryNumberField(
                    label: "Carbs",
                    text: $carbsText,
                    suffix: "g"
                )
                .focused($focusedField, equals: .carbs)

                EditableEntryNumberField(
                    label: "Fat",
                    text: $fatText,
                    suffix: "g"
                )
                .focused($focusedField, equals: .fat)
            }
        }
    }

    // MARK: - Recalculate Button

    private var recalculateButton: some View {
        Button {
            JustWalkHaptics.buttonTap()
            // Create updated entry with current description for recalculation
            var updatedEntry = buildUpdatedEntry()
            updatedEntry.entryDescription = entryDescription
            onRecalculate(updatedEntry)
            dismiss()
        } label: {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "sparkles")
                Text("Recalculate with AI")
            }
            .font(JW.Font.subheadline)
            .foregroundStyle(JW.Color.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .stroke(JW.Color.accent.opacity(0.5), lineWidth: 1)
            )
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
                    Text("Save Changes")
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
                Text("Changes will be saved")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }
        }
        .padding(.top, JW.Spacing.md)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            JustWalkHaptics.buttonTap()
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "trash")
                Text("Delete Entry")
            }
            .font(JW.Font.subheadline)
            .foregroundStyle(JW.Color.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .padding(.top, JW.Spacing.sm)
    }

    // MARK: - Actions

    private func saveEntry() {
        guard isValid else { return }

        let updatedEntry = buildUpdatedEntry()

        JustWalkHaptics.success()
        onSave(updatedEntry)
        dismiss()
    }

    private func buildUpdatedEntry() -> FoodLog {
        FoodLog(
            id: originalEntry.id,
            logID: originalEntry.logID,
            date: originalEntry.date,
            mealType: mealType,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            entryDescription: entryDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: Int(caloriesText) ?? 0,
            protein: Int(proteinText) ?? 0,
            carbs: Int(carbsText) ?? 0,
            fat: Int(fatText) ?? 0,
            source: originalEntry.source,
            createdAt: originalEntry.createdAt,
            modifiedAt: Date()
        )
    }
}

// MARK: - Editable Text Field

private struct EditableEntryTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isMultiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            if isMultiline {
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textPrimary)
                    .lineLimit(3...6)
                    .padding(JW.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: JW.Radius.md)
                            .fill(JW.Color.backgroundTertiary)
                    )
            } else {
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
}

// MARK: - Editable Number Field

private struct EditableEntryNumberField: View {
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

// MARK: - Edit Meal Chip

private struct EditMealChip: View {
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

#Preview("AI Entry") {
    EditFoodEntryView(
        entry: FoodLog(
            date: Date(),
            mealType: .lunch,
            name: "Chipotle Bowl",
            entryDescription: "Chicken burrito bowl with rice, beans, guac, and salsa",
            calories: 920,
            protein: 54,
            carbs: 85,
            fat: 38,
            source: .ai
        ),
        onSave: { _ in },
        onDelete: { _ in },
        onRecalculate: { _ in }
    )
}

#Preview("Manual Entry") {
    EditFoodEntryView(
        entry: FoodLog(
            date: Date(),
            mealType: .breakfast,
            name: "Oatmeal",
            entryDescription: "",
            calories: 300,
            protein: 10,
            carbs: 45,
            fat: 8,
            source: .manual
        ),
        onSave: { _ in },
        onDelete: { _ in },
        onRecalculate: { _ in }
    )
}
