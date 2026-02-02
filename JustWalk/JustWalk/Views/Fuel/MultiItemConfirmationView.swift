//
//  MultiItemConfirmationView.swift
//  JustWalk
//
//  Simplified confirmation view for multiple itemized food entries
//

import SwiftUI

struct MultiItemConfirmationView: View {
    let originalEstimates: [FoodEstimate]
    let mealType: MealType
    let selectedDate: Date
    let onSave: ([FoodLog]) -> Void
    let onCancel: () -> Void

    // Editable state - track which items are included
    @State private var items: [EditableItem]
    @State private var selectedMealType: MealType
    @State private var expandedItemId: UUID?

    @Environment(\.dismiss) private var dismiss

    init(
        originalEstimates: [FoodEstimate],
        mealType: MealType,
        selectedDate: Date,
        onSave: @escaping ([FoodLog]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalEstimates = originalEstimates
        self.mealType = mealType
        self.selectedDate = selectedDate
        self.onSave = onSave
        self.onCancel = onCancel

        // Initialize editable items
        _items = State(initialValue: originalEstimates.map { EditableItem(from: $0) })
        _selectedMealType = State(initialValue: mealType)
    }

    // MARK: - Computed Properties

    private var totalCalories: Int {
        items.filter { $0.isIncluded }.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Int {
        items.filter { $0.isIncluded }.reduce(0) { $0 + $1.protein }
    }

    private var totalCarbs: Int {
        items.filter { $0.isIncluded }.reduce(0) { $0 + $1.carbs }
    }

    private var totalFat: Int {
        items.filter { $0.isIncluded }.reduce(0) { $0 + $1.fat }
    }

    private var includedCount: Int {
        items.filter { $0.isIncluded }.count
    }

    private var isValid: Bool {
        includedCount > 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: JW.Spacing.md) {
                        // AI badge and item count
                        headerSection

                        // Item list
                        itemListSection

                        // Meal type selector
                        mealTypeSection
                    }
                    .padding(.horizontal, JW.Spacing.md)
                    .padding(.top, JW.Spacing.sm)
                    .padding(.bottom, JW.Spacing.lg)
                }

                // Bottom summary and save
                bottomSection
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Review Items")
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

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            HStack(spacing: JW.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                Text("AI Estimate")
                    .font(JW.Font.caption)
            }
            .foregroundStyle(JW.Color.accent)
            .padding(.horizontal, JW.Spacing.sm)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(JW.Color.accent.opacity(0.15))
            )

            Spacer()

            Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)
        }
    }

    // MARK: - Item List Section

    private var itemListSection: some View {
        VStack(spacing: JW.Spacing.sm) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ItemRow(
                    item: $items[index],
                    isExpanded: expandedItemId == item.id,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedItemId == item.id {
                                expandedItemId = nil
                            } else {
                                expandedItemId = item.id
                            }
                        }
                    },
                    onRecalculate: {
                        recalculateItem(at: index)
                    }
                )
            }
        }
    }

    // MARK: - Meal Type Section

    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            Text("Meal")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: JW.Spacing.sm) {
                    ForEach(MealType.allCases.filter { $0 != .unspecified }, id: \.self) { type in
                        Button {
                            selectedMealType = type
                            JustWalkHaptics.selectionChanged()
                        } label: {
                            Text(type.displayName)
                                .font(JW.Font.subheadline)
                                .fontWeight(selectedMealType == type ? .semibold : .medium)
                                .foregroundStyle(selectedMealType == type ? JW.Color.backgroundPrimary : JW.Color.textSecondary)
                                .padding(.horizontal, JW.Spacing.md)
                                .padding(.vertical, JW.Spacing.sm)
                                .background(
                                    Capsule()
                                        .fill(selectedMealType == type ? JW.Color.accent : JW.Color.backgroundTertiary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(JW.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: JW.Spacing.md) {
            // Summary row
            HStack {
                Text("Total")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)

                Spacer()

                HStack(spacing: JW.Spacing.md) {
                    MacroLabel(value: totalCalories, label: "cal", isHighlighted: true)
                    MacroLabel(value: totalProtein, label: "protein")
                    MacroLabel(value: totalCarbs, label: "carbs")
                    MacroLabel(value: totalFat, label: "fat")
                }
            }
            .padding(.horizontal, JW.Spacing.lg)

            // Save button
            Button {
                saveEntries()
            } label: {
                HStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "checkmark")
                    Text("Save \(includedCount) Item\(includedCount == 1 ? "" : "s")")
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
            .padding(.horizontal, JW.Spacing.lg)
        }
        .padding(.vertical, JW.Spacing.lg)
        .background(
            JW.Color.backgroundCard
                .shadow(color: .black.opacity(0.2), radius: 4, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Actions

    private func saveEntries() {
        guard isValid else { return }

        let foodLogs = items
            .filter { $0.isIncluded }
            .map { item in
                FoodLog(
                    date: selectedDate,
                    mealType: selectedMealType,
                    name: item.name,
                    entryDescription: item.description,
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                    source: item.wasEdited ? .aiAdjusted : .ai
                )
            }

        JustWalkHaptics.success()
        onSave(foodLogs)
        dismiss()
    }

    private func recalculateItem(at index: Int) {
        guard index < items.count else { return }
        let description = items[index].description

        items[index].isRecalculating = true

        Task {
            // Treat edited description as a fresh estimation (not adjustment from original)
            // This handles cases where user completely changes the food item
            do {
                let estimate = try await GeminiService.shared.estimateFood(description)

                await MainActor.run {
                    items[index].name = estimate.name
                    items[index].calories = estimate.calories
                    items[index].protein = estimate.protein
                    items[index].carbs = estimate.carbs
                    items[index].fat = estimate.fat
                    items[index].isRecalculating = false
                    items[index].checkIfEdited()
                    JustWalkHaptics.success()
                }
            } catch {
                await MainActor.run {
                    items[index].isRecalculating = false
                    JustWalkHaptics.error()
                }
            }
        }
    }
}

// MARK: - Editable Item Model

private struct EditableItem: Identifiable {
    let id = UUID()
    var name: String
    var description: String  // Editable description
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var isIncluded: Bool = true
    var wasEdited: Bool = false
    var isRecalculating: Bool = false

    let originalName: String
    let originalDescription: String
    let originalCalories: Int
    let originalProtein: Int
    let originalCarbs: Int
    let originalFat: Int

    init(from estimate: FoodEstimate) {
        self.name = estimate.name
        self.description = estimate.description
        self.calories = estimate.calories
        self.protein = estimate.protein
        self.carbs = estimate.carbs
        self.fat = estimate.fat

        self.originalName = estimate.name
        self.originalDescription = estimate.description
        self.originalCalories = estimate.calories
        self.originalProtein = estimate.protein
        self.originalCarbs = estimate.carbs
        self.originalFat = estimate.fat
    }

    mutating func checkIfEdited() {
        wasEdited = name != originalName ||
                    description != originalDescription ||
                    calories != originalCalories ||
                    protein != originalProtein ||
                    carbs != originalCarbs ||
                    fat != originalFat
    }

    var descriptionChanged: Bool {
        description != originalDescription
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    @Binding var item: EditableItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onRecalculate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onToggleExpand) {
                HStack(spacing: JW.Spacing.md) {
                    // Include toggle
                    Button {
                        item.isIncluded.toggle()
                        JustWalkHaptics.selectionChanged()
                    } label: {
                        Image(systemName: item.isIncluded ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(item.isIncluded ? JW.Color.accent : JW.Color.textTertiary)
                    }
                    .buttonStyle(.plain)

                    // Name and loading indicator
                    HStack(spacing: JW.Spacing.sm) {
                        Text(item.name)
                            .font(JW.Font.body)
                            .foregroundStyle(item.isIncluded ? JW.Color.textPrimary : JW.Color.textTertiary)
                            .lineLimit(1)

                        if item.isRecalculating {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    Spacer()

                    // Calories
                    Text("\(item.calories)")
                        .font(JW.Font.body.monospacedDigit())
                        .foregroundStyle(item.isIncluded ? JW.Color.accent : JW.Color.textTertiary)

                    Text("cal")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textTertiary)

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(JW.Color.textTertiary)
                }
                .padding(.horizontal, JW.Spacing.lg)
                .padding(.vertical, JW.Spacing.md)
            }
            .buttonStyle(.plain)

            // Expanded edit section
            if isExpanded {
                ExpandedEditSection(item: $item, onRecalculate: onRecalculate)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
    }
}

// MARK: - Expanded Edit Section

private struct ExpandedEditSection: View {
    @Binding var item: EditableItem
    let onRecalculate: () -> Void

    var body: some View {
        VStack(spacing: JW.Spacing.md) {
            Divider()
                .background(JW.Color.backgroundTertiary)

            // Description edit with recalculate button
            VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                HStack {
                    Text("Description")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)

                    Spacer()

                    Text("Edit to update AI estimate")
                        .font(.system(size: 10))
                        .foregroundStyle(JW.Color.textTertiary)
                }

                HStack(spacing: JW.Spacing.sm) {
                    TextField("What you ate...", text: $item.description, axis: .vertical)
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textPrimary)
                        .lineLimit(2...4)
                        .padding(JW.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: JW.Radius.sm)
                                .fill(JW.Color.backgroundTertiary)
                        )
                        .onChange(of: item.description) { _, _ in item.checkIfEdited() }

                    // Recalculate button
                    Button {
                        JustWalkHaptics.buttonTap()
                        onRecalculate()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                            Text("Re-est")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(item.isRecalculating ? JW.Color.textTertiary : JW.Color.accent)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: JW.Radius.sm)
                                .fill(JW.Color.accent.opacity(0.15))
                        )
                    }
                    .disabled(item.isRecalculating || item.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // Name edit
            HStack {
                Text("Name")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
                    .frame(width: 50, alignment: .leading)

                TextField("Name", text: $item.name)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textPrimary)
                    .padding(JW.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: JW.Radius.sm)
                            .fill(JW.Color.backgroundTertiary)
                    )
                    .onChange(of: item.name) { _, _ in item.checkIfEdited() }
            }

            // Macros in compact grid
            HStack(spacing: JW.Spacing.sm) {
                CompactNumberField(label: "Cal", value: $item.calories, isHighlighted: true)
                    .onChange(of: item.calories) { _, _ in item.checkIfEdited() }
                CompactNumberField(label: "Protein", value: $item.protein, suffix: "g")
                    .onChange(of: item.protein) { _, _ in item.checkIfEdited() }
                CompactNumberField(label: "Carbs", value: $item.carbs, suffix: "g")
                    .onChange(of: item.carbs) { _, _ in item.checkIfEdited() }
                CompactNumberField(label: "Fat", value: $item.fat, suffix: "g")
                    .onChange(of: item.fat) { _, _ in item.checkIfEdited() }
            }
        }
        .padding(.horizontal, JW.Spacing.lg)
        .padding(.bottom, JW.Spacing.md)
    }
}

// MARK: - Compact Number Field

private struct CompactNumberField: View {
    let label: String
    @Binding var value: Int
    var suffix: String? = nil
    var isHighlighted: Bool = false

    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)

            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .font(JW.Font.subheadline.monospacedDigit())
                    .foregroundStyle(isHighlighted ? JW.Color.accent : JW.Color.textPrimary)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 36)
                    .onChange(of: text) { _, newValue in
                        if let intValue = Int(newValue) {
                            value = intValue
                        }
                    }

                if let suffix = suffix {
                    Text(suffix)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(.horizontal, JW.Spacing.sm)
            .padding(.vertical, JW.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.sm)
                    .fill(JW.Color.backgroundTertiary)
            )
        }
        .onAppear {
            text = String(value)
        }
        .onChange(of: value) { _, newValue in
            // Sync text when value changes externally (e.g., from recalculation)
            let newText = String(newValue)
            if text != newText {
                text = newText
            }
        }
    }
}

// MARK: - Macro Label

private struct MacroLabel: View {
    let value: Int
    let label: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(JW.Font.body.monospacedDigit())
                .foregroundStyle(isHighlighted ? JW.Color.accent : JW.Color.textPrimary)

            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)
        }
    }
}

// MARK: - Previews

#Preview("Multiple Items") {
    MultiItemConfirmationView(
        originalEstimates: [
            FoodEstimate(
                name: "Burger",
                description: "burger, fries, and a coke",
                calories: 550,
                protein: 28,
                carbs: 40,
                fat: 30,
                confidence: .medium
            ),
            FoodEstimate(
                name: "Fries",
                description: "burger, fries, and a coke",
                calories: 380,
                protein: 4,
                carbs: 48,
                fat: 19,
                confidence: .medium
            ),
            FoodEstimate(
                name: "Large Coke",
                description: "burger, fries, and a coke",
                calories: 290,
                protein: 0,
                carbs: 77,
                fat: 0,
                confidence: .high
            )
        ],
        mealType: .lunch,
        selectedDate: Date(),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Single Item") {
    MultiItemConfirmationView(
        originalEstimates: [
            FoodEstimate(
                name: "Chipotle Bowl",
                description: "chipotle bowl with chicken",
                calories: 785,
                protein: 42,
                carbs: 68,
                fat: 32,
                confidence: .high
            )
        ],
        mealType: .lunch,
        selectedDate: Date(),
        onSave: { _ in },
        onCancel: {}
    )
}
