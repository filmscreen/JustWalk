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
    @Binding var isMinimized: Bool
    @Binding var requestFocus: Bool  // Parent can set this to request focus
    let onLogTapped: () -> Void
    let onAddManuallyTapped: () -> Void

    @FocusState private var isTextFieldFocused: Bool
    @State private var shouldFocusOnExpand: Bool = false
    @State private var showMealPicker: Bool = false

    private var isLogButtonEnabled: Bool {
        !foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isMinimized {
                minimizedView
            } else {
                expandedView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isMinimized)
        .onAppear {
            // Set smart default meal type based on time only if unspecified
            // This preserves pre-selections from "Add to [meal]" buttons
            if selectedMealType == .unspecified {
                selectedMealType = smartMealType()
            }
        }
        .onChange(of: isMinimized) { _, newValue in
            // When expanding and shouldFocusOnExpand is true, focus the text field
            // (triggers dictation on iOS)
            if !newValue && shouldFocusOnExpand {
                // Small delay to allow view to expand first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                    shouldFocusOnExpand = false
                }
            }
        }
        .onChange(of: requestFocus) { _, newValue in
            // When parent requests focus, focus the text field
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                    requestFocus = false
                }
            }
        }
        .sheet(isPresented: $showMealPicker) {
            mealPickerSheet
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Minimized View

    private var minimizedView: some View {
        HStack(spacing: 0) {
            // Main tappable area - expands without dictation
            Button(action: {
                JustWalkHaptics.buttonTap()
                isMinimized = false
            }) {
                HStack(spacing: JW.Spacing.md) {
                    // Icon
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(JW.Color.accent)

                    // Text
                    Text("What did you eat? (\"1 bagel and 1 cup of OJ\")")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .lineLimit(1)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Mic button - expands AND starts dictation
            Button(action: {
                JustWalkHaptics.buttonTap()
                shouldFocusOnExpand = true
                isMinimized = false
            }) {
                HStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(JW.Color.accent)

                    // Expand indicator
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(JW.Color.textTertiary)
                }
                .padding(.leading, JW.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressButtonStyle())
        }
        .padding(.horizontal, JW.Spacing.lg)
        .padding(.vertical, JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(spacing: JW.Spacing.md) {
            // Text input area with inline minimize button
            textInputArea

            // Action row: Manual | Meal Selector | Log button | Minimize
            HStack(spacing: JW.Spacing.sm) {
                // Add manually link on left
                addManuallyLink

                Spacer()

                // Meal type selector pill
                mealTypePill

                // Log button
                logButton

                // Minimize button
                Button(action: {
                    JustWalkHaptics.buttonTap()
                    isTextFieldFocused = false
                    isMinimized = true
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(JW.Color.textTertiary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: JW.Radius.sm)
                                .fill(JW.Color.backgroundTertiary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(JW.Spacing.md)
        .jwCard()
    }

    // MARK: - Subviews

    private var textInputArea: some View {
        HStack(alignment: .top, spacing: JW.Spacing.sm) {
            // Text input
            ZStack(alignment: .topLeading) {
                // Placeholder
                if foodDescription.isEmpty {
                    Text("What did you eat? (\"1 bagel and 1 cup of OJ\")")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textTertiary)
                        .padding(.horizontal, JW.Spacing.xs)
                        .padding(.vertical, JW.Spacing.sm)
                }

                // Text editor
                TextEditor(text: $foodDescription)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isTextFieldFocused)
                    .frame(minHeight: 44, maxHeight: 72)
            }

            // Voice dictation button
            Button(action: {
                JustWalkHaptics.buttonTap()
                isTextFieldFocused = true
            }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(JW.Color.accent.opacity(0.15))
                    )
            }
            .buttonStyle(ScalePressButtonStyle())
        }
        .padding(JW.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundTertiary)
        )
    }

    private var mealTypePill: some View {
        Button(action: {
            JustWalkHaptics.buttonTap()
            showMealPicker = true
        }) {
            HStack(spacing: 4) {
                Text(selectedMealType.icon)
                    .font(.system(size: 12))
                Text(selectedMealType.displayName)
                    .font(JW.Font.caption.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(JW.Color.textSecondary)
            .padding(.horizontal, JW.Spacing.sm)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(JW.Color.backgroundTertiary)
            )
        }
        .buttonStyle(.plain)
    }

    private var logButton: some View {
        Button(action: {
            guard isLogButtonEnabled else { return }
            isTextFieldFocused = false
            JustWalkHaptics.buttonTap()
            onLogTapped()
        }) {
            HStack(spacing: JW.Spacing.xs) {
                Image(systemName: "sparkles")
                Text("Log it")
            }
            .font(JW.Font.subheadline.weight(.semibold))
            .foregroundStyle(isLogButtonEnabled ? JW.Color.backgroundPrimary : JW.Color.textTertiary)
            .padding(.horizontal, JW.Spacing.lg)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.sm)
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
            Text("Manual")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.accentBlue)
        }
    }

    // MARK: - Meal Picker Sheet

    private var mealPickerSheet: some View {
        VStack(spacing: JW.Spacing.lg) {
            // Header
            Text("Select Meal")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)
                .padding(.top, JW.Spacing.md)

            // Meal options
            VStack(spacing: JW.Spacing.sm) {
                ForEach(MealType.allCases.filter { $0 != .unspecified }, id: \.self) { type in
                    mealOptionRow(type)
                }
            }
            .padding(.horizontal, JW.Spacing.lg)

            Spacer()
        }
        .background(JW.Color.backgroundPrimary)
    }

    private func mealOptionRow(_ type: MealType) -> some View {
        let isSelected = selectedMealType == type

        return Button {
            JustWalkHaptics.selectionChanged()
            selectedMealType = type
            showMealPicker = false
        } label: {
            HStack(spacing: JW.Spacing.md) {
                Text(type.icon)
                    .font(.system(size: 20))

                Text(type.displayName)
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(JW.Color.accent)
                }
            }
            .padding(.horizontal, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .fill(isSelected ? JW.Color.accent.opacity(0.1) : JW.Color.backgroundCard)
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Previews

#Preview("Expanded") {
    struct PreviewWrapper: View {
        @State private var foodDescription = ""
        @State private var mealType: MealType = .lunch
        @State private var isMinimized = false
        @State private var requestFocus = false

        var body: some View {
            VStack {
                Spacer()
                FoodInputView(
                    foodDescription: $foodDescription,
                    selectedMealType: $mealType,
                    isMinimized: $isMinimized,
                    requestFocus: $requestFocus,
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

#Preview("Minimized") {
    struct PreviewWrapper: View {
        @State private var foodDescription = ""
        @State private var mealType: MealType = .lunch
        @State private var isMinimized = true
        @State private var requestFocus = false

        var body: some View {
            VStack {
                Spacer()
                FoodInputView(
                    foodDescription: $foodDescription,
                    selectedMealType: $mealType,
                    isMinimized: $isMinimized,
                    requestFocus: $requestFocus,
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
        @State private var isMinimized = false
        @State private var requestFocus = false

        var body: some View {
            VStack {
                Spacer()
                FoodInputView(
                    foodDescription: $foodDescription,
                    selectedMealType: $mealType,
                    isMinimized: $isMinimized,
                    requestFocus: $requestFocus,
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

#Preview("Dinner Time") {
    struct PreviewWrapper: View {
        @State private var foodDescription = ""
        @State private var mealType: MealType = .dinner
        @State private var isMinimized = false
        @State private var requestFocus = false

        var body: some View {
            VStack {
                Text("Shows Dinner as selected")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
                Spacer()
                FoodInputView(
                    foodDescription: $foodDescription,
                    selectedMealType: $mealType,
                    isMinimized: $isMinimized,
                    requestFocus: $requestFocus,
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
