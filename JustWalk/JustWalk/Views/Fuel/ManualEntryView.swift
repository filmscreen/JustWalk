//
//  ManualEntryView.swift
//  JustWalk
//
//  Manual entry form for adding food logs with direct input
//

import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedDate: Date
    let initialMealType: MealType
    let onSave: (FoodLog) -> Void

    @State private var name: String = ""
    @State private var entryDescription: String = ""
    @State private var mealType: MealType
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    init(
        selectedDate: Date,
        initialMealType: MealType = .unspecified,
        onSave: @escaping (FoodLog) -> Void
    ) {
        self.selectedDate = selectedDate
        self.initialMealType = initialMealType
        self.onSave = onSave
        _mealType = State(initialValue: initialMealType)
    }

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, description, calories, protein, carbs, fat
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !caloriesText.isEmpty &&
        (Int(caloriesText) ?? -1) >= 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JW.Spacing.xl) {
                    // Basic info section
                    formSection("What did you eat?") {
                        FormTextField(
                            placeholder: "Name",
                            text: $name,
                            isRequired: true
                        )
                        .focused($focusedField, equals: .name)

                        FormTextField(
                            placeholder: "Description (optional)",
                            text: $entryDescription
                        )
                        .focused($focusedField, equals: .description)
                    }

                    // Meal type section
                    formSection("Meal type") {
                        mealTypeSelector
                    }

                    // Nutrition section
                    formSection("Nutrition") {
                        FormNumberField(
                            label: "Calories",
                            placeholder: "0",
                            text: $caloriesText,
                            isRequired: true
                        )
                        .focused($focusedField, equals: .calories)

                        HStack(spacing: JW.Spacing.md) {
                            FormNumberField(
                                label: "Protein",
                                placeholder: "0",
                                text: $proteinText,
                                suffix: "g"
                            )
                            .focused($focusedField, equals: .protein)

                            FormNumberField(
                                label: "Carbs",
                                placeholder: "0",
                                text: $carbsText,
                                suffix: "g"
                            )
                            .focused($focusedField, equals: .carbs)

                            FormNumberField(
                                label: "Fat",
                                placeholder: "0",
                                text: $fatText,
                                suffix: "g"
                            )
                            .focused($focusedField, equals: .fat)
                        }
                    }
                }
                .padding(JW.Spacing.lg)
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Add Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        JustWalkHaptics.buttonTap()
                        dismiss()
                    }
                    .foregroundStyle(JW.Color.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isFormValid ? JW.Color.accent : JW.Color.textTertiary)
                    .disabled(!isFormValid)
                }
            }
            .toolbarBackground(JW.Color.backgroundCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            // Only set smart default if no meal type was pre-selected
            if mealType == .unspecified {
                mealType = smartMealType()
            }
        }
    }

    // MARK: - Subviews

    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: JW.Spacing.md) {
            Text(title)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            VStack(spacing: JW.Spacing.sm) {
                content()
            }
        }
    }

    private var mealTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: JW.Spacing.sm) {
                ForEach(MealType.allCases, id: \.self) { type in
                    MealTypePill(
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

    // MARK: - Actions

    private func saveEntry() {
        guard isFormValid else { return }

        let foodLog = FoodLog(
            date: selectedDate,
            mealType: mealType,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            entryDescription: entryDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: Int(caloriesText) ?? 0,
            protein: Int(proteinText) ?? 0,
            carbs: Int(carbsText) ?? 0,
            fat: Int(fatText) ?? 0,
            source: .manual
        )

        JustWalkHaptics.success()
        onSave(foodLog)
        dismiss()
    }

    private func smartMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 0..<11:
            return .breakfast
        case 11..<14:
            return .lunch
        case 14..<17:
            return .snack
        default:
            return .dinner
        }
    }
}

// MARK: - Form Text Field

private struct FormTextField: View {
    let placeholder: String
    @Binding var text: String
    var isRequired: Bool = false

    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textPrimary)

            if isRequired && text.isEmpty {
                Text("Required")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.danger.opacity(0.7))
            }
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Form Number Field

private struct FormNumberField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var suffix: String? = nil
    var isRequired: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            HStack(spacing: JW.Spacing.xs) {
                Text(label)
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)

                if isRequired {
                    Text("*")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.danger)
                }
            }

            HStack(spacing: JW.Spacing.xs) {
                TextField(placeholder, text: $text)
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textPrimary)
                    .keyboardType(.numberPad)

                if let suffix = suffix {
                    Text(suffix)
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(JW.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Meal Type Pill

private struct MealTypePill: View {
    let mealType: MealType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(mealType.displayName)
                .font(JW.Font.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? JW.Color.backgroundPrimary : JW.Color.textSecondary)
                .padding(.horizontal, JW.Spacing.md)
                .padding(.vertical, JW.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? JW.Color.accent : JW.Color.backgroundCard)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Empty Form") {
    ManualEntryView(
        selectedDate: Date(),
        onSave: { log in
            print("Saved: \(log.name) - \(log.calories) cal")
        }
    )
}

#Preview("Filled Form") {
    struct PreviewWrapper: View {
        var body: some View {
            ManualEntryView(
                selectedDate: Date(),
                onSave: { log in
                    print("Saved: \(log.name) - \(log.calories) cal")
                }
            )
        }
    }

    return PreviewWrapper()
}
