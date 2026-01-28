//
//  GoalSettingView.swift
//  JustWalk
//
//  Screen 6: Simplified goal selection — three presets + custom sheet
//

import SwiftUI

struct GoalSettingView: View {
    let onComplete: () -> Void

    @State private var selectedGoal: Int = 7000
    @State private var showCustomInput = false

    private let goalOptions: [(value: Int, label: String, recommended: Bool)] = [
        (5000, "A good starting point.", false),
        (7000, "Builds a real habit.", true),
        (10000, "The classic benchmark.", false)
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: JW.Spacing.lg) {
                    // Header
                    VStack(spacing: JW.Spacing.sm) {
                        Text("Your Daily Goal.")
                            .font(JW.Font.title1)
                            .foregroundStyle(JW.Color.textPrimary)
                            .staggeredAppearance(index: 0, delay: 0.1)

                        Text("Pick something you can hit most days.\nYou can always change it later.")
                            .font(JW.Font.body)
                            .foregroundStyle(JW.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, JW.Spacing.lg)
                            .staggeredAppearance(index: 1, delay: 0.1)
                    }
                    .padding(.top, JW.Spacing.xl)

                    // Goal options
                    VStack(spacing: JW.Spacing.md) {
                        ForEach(goalOptions, id: \.value) { option in
                            GoalOptionCard(
                                value: option.value,
                                label: option.label,
                                recommended: option.recommended,
                                isSelected: selectedGoal == option.value
                            ) {
                                selectedGoal = option.value
                                JustWalkHaptics.selectionChanged()
                            }
                        }
                    }
                    .padding(.horizontal, JW.Spacing.xl)
                    .staggeredAppearance(index: 2, delay: 0.1)

                    // Custom option
                    Button {
                        showCustomInput = true
                    } label: {
                        Text("Other amount →")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                    .staggeredAppearance(index: 3, delay: 0.1)
                }
                .padding(.bottom, JW.Spacing.lg)
            }

            // Set Goal button — fixed at bottom
            Button(action: { setGoal() }) {
                Text("Set My Goal")
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, JW.Spacing.xl)
            .staggeredAppearance(index: 4, delay: 0.1)
        }
        .sheet(isPresented: $showCustomInput) {
            CustomGoalSheet(
                initialValue: selectedGoal,
                onSave: { value in
                    selectedGoal = value
                    showCustomInput = false
                }
            )
        }
    }

    // MARK: - Actions

    private func setGoal() {
        var profile = PersistenceManager.shared.loadProfile()
        profile.dailyStepGoal = selectedGoal
        PersistenceManager.shared.saveProfile(profile)
        UserDefaults.standard.set(selectedGoal, forKey: "dailyStepGoal")
        onComplete()
    }
}

// MARK: - Goal Option Card

private struct GoalOptionCard: View {
    let value: Int
    let label: String
    let recommended: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                HStack(spacing: JW.Spacing.lg) {
                    // Radio button
                    ZStack {
                        Circle()
                            .stroke(isSelected ? JW.Color.accent : JW.Color.textTertiary, lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(JW.Color.accent)
                                .frame(width: 14, height: 14)
                        }
                    }

                    // Step count
                    Text(value.formatted())
                        .font(JW.Font.headline)
                        .foregroundStyle(isSelected ? JW.Color.accent : JW.Color.textPrimary)

                    // Recommended badge
                    if recommended {
                        Text("Recommended")
                            .font(JW.Font.caption.weight(.medium))
                            .foregroundStyle(JW.Color.accent)
                            .padding(.horizontal, JW.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(JW.Color.accent.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.sm))
                    }

                    Spacer()
                }

                // Description
                HStack {
                    Spacer().frame(width: 40)
                    Text(label)
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                    Spacer()
                }
            }
            .padding(JW.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .stroke(isSelected ? JW.Color.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
        )
    }
}

// MARK: - Custom Goal Sheet

private struct CustomGoalSheet: View {
    let initialValue: Int
    let onSave: (Int) -> Void

    @State private var value: Double
    @Environment(\.dismiss) var dismiss

    init(initialValue: Int, onSave: @escaping (Int) -> Void) {
        self.initialValue = initialValue
        self.onSave = onSave
        self._value = State(initialValue: Double(initialValue))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: JW.Spacing.xxl) {
                Text("\(Int(value).formatted())")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(JW.Color.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)

                Text("steps per day")
                    .font(JW.Font.title3)
                    .foregroundStyle(JW.Color.textSecondary)

                Slider(value: $value, in: 3000...15000, step: 500)
                    .tint(JW.Color.accent)
                    .padding(.horizontal, JW.Spacing.xxl)

                HStack {
                    Text("3,000")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                    Spacer()
                    Text("15,000")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
                .padding(.horizontal, JW.Spacing.xxl)

                Spacer()
            }
            .padding(.top, 40)
            .background(JW.Color.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Custom Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(JW.Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(Int(value)) }
                        .fontWeight(.semibold)
                        .foregroundStyle(JW.Color.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews

#Preview("Goal Setting") {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        GoalSettingView(onComplete: { print("Onboarding complete") })
    }
}
