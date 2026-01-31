//
//  FoodInputView.swift
//  JustWalk
//
//  Text input area for describing food with meal type selection
//

import SwiftUI

struct FoodInputView: View {
    @Binding var foodDescription: String
    @Binding var selectedMealType: MealType
    let onLogTapped: () -> Void
    let onAddManuallyTapped: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    private var isLogButtonEnabled: Bool {
        !foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: JW.Spacing.lg) {
            // Text input area
            textInputArea

            // Meal type selector
            mealTypeSelector

            // Action buttons
            VStack(spacing: JW.Spacing.md) {
                logButton
                addManuallyLink
            }
        }
        .padding(JW.Spacing.lg)
        .jwCard()
        .onAppear {
            // Set smart default meal type based on time only if unspecified
            // This preserves pre-selections from "Add to [meal]" buttons
            if selectedMealType == .unspecified {
                selectedMealType = smartMealType()
            }
        }
    }

    // MARK: - Subviews

    private var textInputArea: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if foodDescription.isEmpty {
                Text("What did you eat?")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textTertiary)
                    .padding(.horizontal, JW.Spacing.sm)
                    .padding(.vertical, JW.Spacing.md)
            }

            // Text editor
            TextEditor(text: $foodDescription)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isTextFieldFocused)
                .frame(minHeight: 80, maxHeight: 120)
        }
        .padding(JW.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundTertiary)
        )
    }

    private var mealTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: JW.Spacing.sm) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    MealTypeButton(
                        mealType: mealType,
                        isSelected: selectedMealType == mealType
                    ) {
                        selectedMealType = mealType
                        JustWalkHaptics.selectionChanged()
                    }
                }
            }
        }
    }

    private var logButton: some View {
        Button(action: {
            guard isLogButtonEnabled else { return }
            isTextFieldFocused = false
            JustWalkHaptics.buttonTap()
            onLogTapped()
        }) {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "sparkles")
                Text("Log it")
            }
            .font(JW.Font.headline)
            .foregroundStyle(isLogButtonEnabled ? JW.Color.backgroundPrimary : JW.Color.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, JW.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .fill(isLogButtonEnabled ? JW.Color.accent : JW.Color.backgroundTertiary)
            )
        }
        .disabled(!isLogButtonEnabled)
        .buttonStyle(ScalePressButtonStyle())
    }

    private var addManuallyLink: some View {
        Button(action: {
            JustWalkHaptics.buttonTap()
            onAddManuallyTapped()
        }) {
            Text("Add manually")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.accentBlue)
        }
    }

    // MARK: - Smart Meal Type

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

// MARK: - Meal Type Button

private struct MealTypeButton: View {
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
                        .fill(isSelected ? JW.Color.accent : JW.Color.backgroundTertiary)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Empty State") {
    struct PreviewWrapper: View {
        @State private var foodDescription = ""
        @State private var mealType: MealType = .lunch

        var body: some View {
            ScrollView {
                FoodInputView(
                    foodDescription: $foodDescription,
                    selectedMealType: $mealType,
                    onLogTapped: { print("Log tapped") },
                    onAddManuallyTapped: { print("Add manually tapped") }
                )
                .padding()
            }
            .background(JW.Color.backgroundPrimary)
        }
    }

    return PreviewWrapper()
}

#Preview("With Text") {
    struct PreviewWrapper: View {
        @State private var foodDescription = "Chipotle bowl with chicken, rice, black beans, guac, and salsa"
        @State private var mealType: MealType = .lunch

        var body: some View {
            ScrollView {
                FoodInputView(
                    foodDescription: $foodDescription,
                    selectedMealType: $mealType,
                    onLogTapped: { print("Log tapped") },
                    onAddManuallyTapped: { print("Add manually tapped") }
                )
                .padding()
            }
            .background(JW.Color.backgroundPrimary)
        }
    }

    return PreviewWrapper()
}

#Preview("Morning Time") {
    struct PreviewWrapper: View {
        @State private var foodDescription = ""
        @State private var mealType: MealType = .breakfast

        var body: some View {
            ScrollView {
                FoodInputView(
                    foodDescription: $foodDescription,
                    selectedMealType: $mealType,
                    onLogTapped: { print("Log tapped") },
                    onAddManuallyTapped: { print("Add manually tapped") }
                )
                .padding()

                Text("Default should be Breakfast (before 11am)")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }
            .background(JW.Color.backgroundPrimary)
        }
    }

    return PreviewWrapper()
}
