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

    private var canRecalculate: Bool {
        !entryDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                VStack(spacing: JW.Spacing.md) {
                    // Source badge (centered)
                    sourceBadge
                        .padding(.bottom, JW.Spacing.xs)

                    // Name card
                    nameCard

                    // Description card with Re-estimate
                    descriptionCard

                    // Macros card (2×2 grid)
                    macrosCard

                    // Meal selector (no card)
                    mealSelector

                    // Save button
                    saveButton
                        .padding(.top, JW.Spacing.sm)

                    // Delete button
                    deleteButton
                }
                .padding(.horizontal, JW.Spacing.lg)
                .padding(.top, JW.Spacing.md)
                .padding(.bottom, JW.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
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
        HStack(spacing: JW.Spacing.xs) {
            Image(systemName: sourceIcon)
                .font(.system(size: 12))
            Text(sourceText)
                .font(JW.Font.caption)
        }
        .foregroundStyle(sourceColor)
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(sourceColor.opacity(0.12))
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

    // MARK: - Name Card

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            Text("Name")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            TextField("Food name", text: $name)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)
                .focused($focusedField, equals: .name)
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
    }

    // MARK: - Description Card

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            Text("Description")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            TextField("What you ate...", text: $entryDescription, axis: .vertical)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textPrimary)
                .lineLimit(2...5)
                .focused($focusedField, equals: .description)

            // Re-estimate button
            Button {
                JustWalkHaptics.buttonTap()
                var updatedEntry = buildUpdatedEntry()
                updatedEntry.entryDescription = entryDescription
                onRecalculate(updatedEntry)
                dismiss()
            } label: {
                HStack(spacing: JW.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Re-estimate")
                        .font(JW.Font.subheadline.weight(.medium))
                }
                .foregroundStyle(canRecalculate ? JW.Color.accent : JW.Color.textTertiary)
                .padding(.vertical, JW.Spacing.sm)
            }
            .disabled(!canRecalculate)
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
    }

    // MARK: - Macros Card (2×2 Grid)

    private var macrosCard: some View {
        VStack(spacing: JW.Spacing.lg) {
            // Top row: Calories and Protein
            HStack(spacing: JW.Spacing.lg) {
                // Calories (prominent, green)
                macroCell(
                    value: $caloriesText,
                    label: "Cal",
                    isCalories: true,
                    field: .calories
                )

                // Protein
                macroCell(
                    value: $proteinText,
                    label: "Protein",
                    suffix: "g",
                    field: .protein
                )
            }

            // Bottom row: Carbs and Fat
            HStack(spacing: JW.Spacing.lg) {
                // Carbs
                macroCell(
                    value: $carbsText,
                    label: "Carbs",
                    suffix: "g",
                    field: .carbs
                )

                // Fat
                macroCell(
                    value: $fatText,
                    label: "Fat",
                    suffix: "g",
                    field: .fat
                )
            }
        }
        .padding(JW.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
    }

    private func macroCell(
        value: Binding<String>,
        label: String,
        suffix: String? = nil,
        isCalories: Bool = false,
        field: Field
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                TextField("0", text: value)
                    .font(isCalories ? .system(size: 32, weight: .bold, design: .rounded) : .system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(isCalories ? JW.Color.accent : JW.Color.textPrimary)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: field)

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }

            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Meal Selector

    private var mealSelector: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            Text("Meal")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: JW.Spacing.sm) {
                    ForEach(MealType.allCases.filter { $0 != .unspecified }, id: \.self) { type in
                        mealPill(type)
                    }
                }
            }
        }
    }

    private func mealPill(_ type: MealType) -> some View {
        let isSelected = mealType == type

        return Button {
            mealType = type
            JustWalkHaptics.selectionChanged()
        } label: {
            HStack(spacing: JW.Spacing.xs) {
                Text(type.icon)
                    .font(.system(size: 14))
                Text(type.displayName)
                    .font(JW.Font.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .black : JW.Color.textSecondary)
            .padding(.horizontal, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? JW.Color.accent : JW.Color.backgroundCard)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveEntry()
        } label: {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
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
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            JustWalkHaptics.buttonTap()
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: JW.Spacing.xs) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text("Delete Entry")
            }
            .font(JW.Font.subheadline)
            .foregroundStyle(JW.Color.danger)
        }
        .padding(.vertical, JW.Spacing.sm)
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

// MARK: - Previews

#Preview("AI Entry") {
    EditFoodEntryView(
        entry: FoodLog(
            date: Date(),
            mealType: .dinner,
            name: "Chicken Thighs",
            entryDescription: "4 chicken thighs",
            calories: 1040,
            protein: 104,
            carbs: 0,
            fat: 72,
            source: .ai
        ),
        onSave: { _ in },
        onDelete: { _ in },
        onRecalculate: { _ in }
    )
}

#Preview("AI Adjusted Entry") {
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
            source: .aiAdjusted
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
