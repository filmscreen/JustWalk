//
//  ReturningGoalConfirmView.swift
//  JustWalk
//
//  Goal confirmation screen for returning users.
//  Shows the restored goal with option to keep or change it.
//

import SwiftUI

struct ReturningGoalConfirmView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentGoal: Int
    @State private var showGoalPicker = false
    @State private var hasAdvanced = false

    // Entrance animation
    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showGoalDisplay = false
    @State private var showButtons = false

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
        self._currentGoal = State(initialValue: goal)
    }

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Target/bullseye icon in accent background
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "target")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }
            .scaleEffect(showIcon ? 1 : 0.8)
            .opacity(showIcon ? 1 : 0)

            // Copy
            VStack(spacing: JW.Spacing.md) {
                Text("Your Daily Goal")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)
            }

            // Large goal number display
            VStack(spacing: JW.Spacing.sm) {
                Text("\(currentGoal.formatted())")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(JW.Color.accent)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: currentGoal)

                Text("steps per day")
                    .font(JW.Font.title3)
                    .foregroundStyle(JW.Color.textSecondary)
            }
            .padding(.vertical, JW.Spacing.xl)
            .opacity(showGoalDisplay ? 1 : 0)
            .scaleEffect(showGoalDisplay ? 1 : 0.9)

            Spacer()

            // Action buttons
            VStack(spacing: JW.Spacing.lg) {
                // Keep This Goal - primary button
                Button(action: handleKeepGoal) {
                    Text("Keep This Goal")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                // Change Goal - secondary button
                Button(action: handleChangeGoal) {
                    Text("Change Goal")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
            .opacity(showButtons ? 1 : 0)
            .offset(y: showButtons ? 0 : 20)
        }
        .onAppear { runEntrance() }
        .sheet(isPresented: $showGoalPicker) {
            GoalPickerSheet(
                initialValue: currentGoal,
                onSave: { newGoal in
                    currentGoal = newGoal
                    saveGoal(newGoal)
                    showGoalPicker = false
                }
            )
        }
    }

    // MARK: - Actions

    private func handleKeepGoal() {
        JustWalkHaptics.buttonTap()
        advance()
    }

    private func handleChangeGoal() {
        JustWalkHaptics.buttonTap()
        showGoalPicker = true
    }

    private func saveGoal(_ goal: Int) {
        var profile = PersistenceManager.shared.loadProfile()
        profile.dailyStepGoal = goal
        PersistenceManager.shared.saveProfile(profile)
        UserDefaults.standard.set(goal, forKey: "dailyStepGoal")
    }

    private func advance() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        onContinue()
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick ? Animation.easeOut(duration: 0.2) : JustWalkAnimation.emphasis

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showIcon = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) { showHeadline = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(quick ? 0 : 0.7)) { showGoalDisplay = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.0)) { showButtons = true }

        // Haptic when goal is revealed
        DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0.2 : 0.8)) {
            JustWalkHaptics.selectionChanged()
        }
    }
}

// MARK: - Goal Picker Sheet

private struct GoalPickerSheet: View {
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
            .navigationTitle("Change Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(JW.Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        JustWalkHaptics.buttonTap()
                        onSave(Int(value))
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(JW.Color.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        ReturningGoalConfirmView(onContinue: {})
    }
}
