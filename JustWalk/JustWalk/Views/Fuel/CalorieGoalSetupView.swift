//
//  CalorieGoalSetupView.swift
//  JustWalk
//
//  Setup view for configuring calorie goal based on maintenance calculation
//

import SwiftUI

struct CalorieGoalSetupView: View {
    @ObservedObject private var goalManager = CalorieGoalManager.shared
    @Environment(\.dismiss) private var dismiss

    // Form inputs
    @State private var sex: BiologicalSex = .male
    @State private var ageText: String = "30"
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 8
    @State private var weightText: String = "160"
    @State private var activityLevel: ActivityLevel = .light

    // Goal state
    @State private var goalValue: Int = 2000
    @State private var isEditingGoal: Bool = false
    @State private var goalEditText: String = ""
    @FocusState private var isGoalFieldFocused: Bool

    // Computed maintenance (updates as inputs change)
    private var calculatedMaintenance: Int {
        let age = Int(ageText) ?? 30
        let weight = Double(weightText) ?? 160
        let heightCM = CalorieGoalHelpers.feetInchesToCM(feet: heightFeet, inches: heightInches)
        let weightKG = CalorieGoalHelpers.lbsToKG(lbs: weight)

        return CalorieGoalHelpers.calculateMaintenance(
            sex: sex,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            activityLevel: activityLevel
        )
    }

    private var projection: CalorieGoalHelpers.ProjectionMessage {
        CalorieGoalHelpers.getProjectionMessage(goal: goalValue, maintenance: calculatedMaintenance)
    }

    private var isValid: Bool {
        guard let age = Int(ageText), age >= 13, age <= 120 else { return false }
        guard let weight = Double(weightText), weight >= 50, weight <= 700 else { return false }
        return goalValue >= 1000 && goalValue <= 6000
    }

    private var showLowCalorieWarning: Bool {
        goalValue < 1200
    }

    private var showAggressiveDeficitWarning: Bool {
        calculatedMaintenance - goalValue > 1000
    }

    private var isEditing: Bool {
        goalManager.hasGoal
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JW.Spacing.xl) {
                    // Subtitle
                    Text("We'll calculate a starting point.\nYou can adjust it anytime.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, JW.Spacing.sm)

                    // Input form
                    inputForm

                    // Maintenance display
                    maintenanceDisplay

                    // Goal adjuster
                    goalAdjuster

                    // Projection message
                    projectionDisplay

                    // Warnings
                    warningsSection

                    // Save button
                    saveButton

                    // Delete button (if editing)
                    if isEditing {
                        deleteButton
                    }
                }
                .padding(JW.Spacing.lg)
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Set Your Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                }
            }
            .toolbarBackground(JW.Color.backgroundCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                loadExistingSettings()
            }
        }
    }

    // MARK: - Input Form

    private var inputForm: some View {
        VStack(spacing: 0) {
            // Sex (with helper text)
            VStack(alignment: .leading, spacing: 2) {
                formRow(label: "Sex") {
                    Picker("Sex", selection: $sex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(JW.Color.textPrimary)
                    .fixedSize()
                }

                Text("for metabolic calculation")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
                    .padding(.leading, 0)
            }

            Divider().background(JW.Color.backgroundTertiary)

            // Age
            formRow(label: "Age") {
                TextField("30", text: $ageText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .foregroundStyle(JW.Color.textPrimary)
            }

            Divider().background(JW.Color.backgroundTertiary)

            // Height
            formRow(label: "Height") {
                HStack(spacing: JW.Spacing.sm) {
                    Picker("Feet", selection: $heightFeet) {
                        ForEach(4...7, id: \.self) { ft in
                            Text("\(ft)").tag(ft)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(JW.Color.textPrimary)
                    .fixedSize()

                    Text("ft")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textTertiary)

                    Picker("Inches", selection: $heightInches) {
                        ForEach(0...11, id: \.self) { inch in
                            Text("\(inch)").tag(inch)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(JW.Color.textPrimary)
                    .fixedSize()

                    Text("in")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }

            Divider().background(JW.Color.backgroundTertiary)

            // Weight (with tap affordance)
            formRow(label: "Weight") {
                HStack(spacing: JW.Spacing.xs) {
                    TextField("160", text: $weightText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .foregroundStyle(JW.Color.textPrimary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(JW.Color.backgroundTertiary.opacity(0.5))
                        )

                    Text("lbs")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }

            Divider().background(JW.Color.backgroundTertiary)

            // Activity Level (with descriptions in picker)
            formRow(label: "Activity") {
                Picker("Activity", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text("\(level.displayName) — \(level.description)")
                            .tag(level)
                    }
                }
                .pickerStyle(.menu)
                .tint(JW.Color.textPrimary)
                .fixedSize()
            }
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
        .onChange(of: calculatedMaintenance) { _, newMaintenance in
            // When maintenance changes, update goal to match if it hasn't been adjusted
            if !isEditing && goalValue == 2000 {
                goalValue = newMaintenance
            }
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer()

            content()
        }
        .padding(.vertical, JW.Spacing.sm)
    }

    // MARK: - Maintenance Display

    private var maintenanceDisplay: some View {
        HStack {
            Text("Your maintenance:")
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer()

            Text("\(calculatedMaintenance.formatted()) cal")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard.opacity(0.5))
        )
    }

    // MARK: - Goal Adjuster

    private var goalAdjuster: some View {
        VStack(spacing: JW.Spacing.sm) {
            Text("Your goal:")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            HStack(spacing: JW.Spacing.lg) {
                // Decrease button
                Button {
                    JustWalkHaptics.selectionChanged()
                    goalValue = max(1000, goalValue - 50)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(JW.Color.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(JW.Color.backgroundTertiary)
                        )
                }
                .buttonStyle(.plain)

                // Goal value (tappable to edit)
                if isEditingGoal {
                    TextField("", text: $goalEditText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(JW.Color.accent)
                        .frame(width: 140)
                        .focused($isGoalFieldFocused)
                        .onSubmit {
                            commitGoalEdit()
                        }
                        .onChange(of: isGoalFieldFocused) { _, focused in
                            if !focused {
                                commitGoalEdit()
                            }
                        }
                } else {
                    Button {
                        goalEditText = "\(goalValue)"
                        isEditingGoal = true
                        // Focus the field after a brief delay to allow state update
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isGoalFieldFocused = true
                        }
                    } label: {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(goalValue.formatted())")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(JW.Color.accent)

                            Text("cal")
                                .font(JW.Font.headline)
                                .foregroundStyle(JW.Color.textTertiary)

                            // Tap hint
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(JW.Color.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Increase button
                Button {
                    JustWalkHaptics.selectionChanged()
                    goalValue = min(6000, goalValue + 50)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(JW.Color.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(JW.Color.backgroundTertiary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(JW.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
    }

    // MARK: - Projection Display

    private var projectionDisplay: some View {
        VStack(spacing: JW.Spacing.xs) {
            Text(projection.line1)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            Text(projection.line2)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textPrimary)
        }
        .padding(JW.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard.opacity(0.5))
        )
    }

    // MARK: - Warnings

    @ViewBuilder
    private var warningsSection: some View {
        if showLowCalorieWarning || showAggressiveDeficitWarning {
            VStack(spacing: JW.Spacing.sm) {
                if showLowCalorieWarning {
                    warningRow(text: "Very low — consider consulting a doctor")
                }

                if showAggressiveDeficitWarning && !showLowCalorieWarning {
                    warningRow(text: "Aggressive deficit — may be hard to sustain")
                }
            }
        }
    }

    private func warningRow(text: String) -> some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(JW.Color.streak)

            Text(text)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding(JW.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.sm)
                .fill(JW.Color.streak.opacity(0.1))
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveGoal()
        } label: {
            Text("Save Goal")
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
            deleteGoal()
        } label: {
            Text("Delete Goal")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.danger)
        }
        .padding(.top, JW.Spacing.sm)
    }

    // MARK: - Actions

    private func commitGoalEdit() {
        if let value = Int(goalEditText), value >= 1000, value <= 6000 {
            goalValue = value
        }
        isEditingGoal = false
        isGoalFieldFocused = false
    }

    private func loadExistingSettings() {
        guard let settings = goalManager.settings else {
            // Set initial goal to calculated maintenance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                goalValue = calculatedMaintenance
            }
            return
        }

        // Load existing values
        sex = settings.sex
        ageText = "\(settings.age)"
        let (feet, inches) = CalorieGoalHelpers.cmToFeetInches(cm: settings.heightCM)
        heightFeet = feet
        heightInches = inches
        weightText = "\(Int(CalorieGoalHelpers.kgToLbs(kg: settings.weightKG).rounded()))"
        activityLevel = settings.activityLevel
        goalValue = settings.dailyGoal
    }

    private func saveGoal() {
        guard isValid else { return }

        let age = Int(ageText) ?? 30
        let weight = Double(weightText) ?? 160
        let heightCM = CalorieGoalHelpers.feetInchesToCM(feet: heightFeet, inches: heightInches)
        let weightKG = CalorieGoalHelpers.lbsToKG(lbs: weight)

        let settings = CalorieGoalSettings(
            id: goalManager.settings?.id ?? UUID(),
            settingsID: goalManager.settings?.settingsID,
            dailyGoal: goalValue,
            calculatedMaintenance: calculatedMaintenance,
            sex: sex,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            activityLevel: activityLevel,
            createdAt: goalManager.settings?.createdAt ?? Date()
        )

        JustWalkHaptics.success()
        goalManager.saveGoal(settings)
        dismiss()
    }

    private func deleteGoal() {
        JustWalkHaptics.buttonTap()
        goalManager.deleteGoal()
        dismiss()
    }
}

// MARK: - Preview

#Preview("New Goal") {
    CalorieGoalSetupView()
}

#Preview("Edit Goal") {
    // Note: Would need to set up mock data for edit preview
    CalorieGoalSetupView()
}
