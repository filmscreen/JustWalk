//
//  FuelTabView.swift
//  JustWalk
//
//  Main Fuel tab view assembling calendar, summary, input, and log components
//

import SwiftUI

struct FuelTabView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var foodLogManager = FoodLogManager.shared

    @State private var selectedDate = Date()
    @State private var foodDescription = ""
    @State private var selectedMealType: MealType = .unspecified
    @State private var showManualEntry = false

    // AI estimation state
    @State private var estimationState = FoodEstimationState()
    @State private var showAIConfirmation = false
    @State private var showAIError = false
    @State private var pendingEstimate: FoodEstimate?

    // Edit entry state
    @State private var showEditEntry = false
    @State private var entryToEdit: FoodLog?

    // Recalculate state
    @State private var showRecalculate = false
    @State private var entryToRecalculate: FoodLog?

    private let calendar = Calendar.current

    // MARK: - Computed Properties

    private var dailySummary: (calories: Int, protein: Int, carbs: Int, fat: Int) {
        foodLogManager.getDailySummary(for: selectedDate)
    }

    private var logsByMeal: [MealType: [FoodLog]] {
        foodLogManager.getLogsByMeal(for: selectedDate)
    }

    /// Whether the selected date allows adding/editing entries
    /// True for today and past 7 days, false for future or older dates
    private var isDateEditable: Bool {
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfSelected = calendar.startOfDay(for: selectedDate)

        // Don't allow future dates
        if startOfSelected > startOfToday {
            return false
        }

        // Allow today and past 7 days
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) else {
            return false
        }

        return startOfSelected >= sevenDaysAgo
    }

    /// Message to show when date is read-only
    private var readOnlyMessage: String {
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfSelected = calendar.startOfDay(for: selectedDate)

        if startOfSelected > startOfToday {
            return "Can't add entries for future dates"
        } else {
            return "Entries older than 7 days are read-only"
        }
    }

    // MARK: - Body

    var body: some View {
        if subscriptionManager.isPro {
            fuelTabContent
        } else {
            FuelProGateView()
        }
    }

    // MARK: - Fuel Tab Content

    private var fuelTabContent: some View {
        ScrollView {
            VStack(spacing: JW.Spacing.lg) {
                // Calendar section
                FuelCalendarView(
                    selectedDate: $selectedDate,
                    hasLogsForDate: { foodLogManager.hasLogs(for: $0) }
                )

                // Daily summary section
                DailySummaryView(
                    selectedDate: selectedDate,
                    summary: dailySummary
                )

                // Divider
                sectionDivider

                // Food input section (only for editable dates)
                if isDateEditable {
                    FoodInputView(
                        foodDescription: $foodDescription,
                        selectedMealType: $selectedMealType,
                        onLogTapped: handleLogTapped,
                        onAddManuallyTapped: handleAddManuallyTapped
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    // Read-only notice
                    readOnlyNotice
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Divider
                sectionDivider

                // Today's log section
                FoodLogListView(
                    logsByMeal: logsByMeal,
                    onEntryTapped: { entry in
                        if isDateEditable {
                            handleEntryTapped(entry)
                        }
                    },
                    onAddToMeal: { mealType in
                        if isDateEditable {
                            handleAddToMeal(mealType)
                        }
                    },
                    onDeleteEntry: isDateEditable ? { entry in
                        handleSwipeDelete(entry)
                    } : nil
                )
            }
            .padding(.horizontal, JW.Spacing.lg)
            .padding(.top, JW.Spacing.md)
            .padding(.bottom, JW.Spacing.xxxl)
            .animation(.easeInOut(duration: 0.25), value: isDateEditable)
        }
        .background(JW.Color.backgroundPrimary)
        .overlay {
            // Loading overlay
            if estimationState.isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView(
                selectedDate: selectedDate,
                initialMealType: selectedMealType,
                onSave: handleManualEntrySave
            )
        }
        .sheet(isPresented: $showAIConfirmation) {
            if let estimate = pendingEstimate {
                FoodConfirmationView(
                    originalEstimate: estimate,
                    mealType: selectedMealType,
                    selectedDate: selectedDate,
                    onSave: handleAIConfirm,
                    onCancel: handleAICancel
                )
            }
        }
        .sheet(isPresented: $showEditEntry) {
            if let entry = entryToEdit {
                EditFoodEntryView(
                    entry: entry,
                    onSave: handleEditSave,
                    onDelete: handleEditDelete,
                    onRecalculate: handleEditRecalculate
                )
            }
        }
        .sheet(isPresented: $showRecalculate) {
            if let entry = entryToRecalculate {
                RecalculateComparisonView(
                    currentEntry: entry,
                    onApplyNewEstimate: handleRecalculateApply,
                    onKeepCurrent: handleRecalculateKeep
                )
            }
        }
        .alert("Couldn't Estimate", isPresented: $showAIError) {
            if estimationState.canRetry {
                Button("Try Again") {
                    estimationState.retry()
                }
            }
            if estimationState.canEnterManually {
                Button("Enter Manually") {
                    showManualEntry = true
                }
            }
            Button("Cancel", role: .cancel) {
                estimationState.reset()
            }
        } message: {
            Text(estimationState.errorMessage ?? "Something went wrong. Please try again.")
        }
        .onChange(of: estimationState.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
    }

    // MARK: - Subviews

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, JW.Spacing.sm)
    }

    private var readOnlyNotice: some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))

            Text(readOnlyMessage)
                .font(JW.Font.subheadline)
        }
        .foregroundStyle(JW.Color.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, JW.Spacing.xl)
        .padding(.horizontal, JW.Spacing.lg)
        .jwCard()
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: JW.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(JW.Color.accent)

                Text(estimationState.loadingMessage ?? "Estimating...")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)
            }
            .padding(JW.Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.xl)
                    .fill(JW.Color.backgroundCard)
            )
        }
    }

    // MARK: - Actions

    private func handleLogTapped() {
        guard !foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Start AI estimation
        estimationState.estimate(foodDescription)
    }

    private func handleAddManuallyTapped() {
        showManualEntry = true
    }

    private func handleManualEntrySave(_ log: FoodLog) {
        foodLogManager.addLog(log)
    }

    private func handleEntryTapped(_ entry: FoodLog) {
        entryToEdit = entry
        showEditEntry = true
    }

    private func handleAddToMeal(_ mealType: MealType) {
        // Pre-select meal type for new entry
        selectedMealType = mealType
    }

    // MARK: - AI Flow Handlers

    private func handlePhaseChange(_ phase: FoodEstimationState.Phase) {
        switch phase {
        case .idle, .loading:
            break

        case .success(let estimate):
            pendingEstimate = estimate
            showAIConfirmation = true

        case .error:
            showAIError = true
        }
    }

    private func handleAIConfirm(_ foodLog: FoodLog) {
        foodLogManager.addLog(foodLog)
        foodDescription = ""
        pendingEstimate = nil
        estimationState.reset()
    }

    private func handleAICancel() {
        pendingEstimate = nil
        estimationState.reset()
    }

    // MARK: - Edit Entry Handlers

    private func handleEditSave(_ updatedLog: FoodLog) {
        foodLogManager.updateLog(updatedLog)
        entryToEdit = nil
    }

    private func handleEditDelete(_ log: FoodLog) {
        foodLogManager.deleteLog(log)
        entryToEdit = nil
    }

    private func handleEditRecalculate(_ log: FoodLog) {
        // Close edit sheet and show recalculate view
        entryToEdit = nil
        showEditEntry = false

        // Small delay to let the sheet dismiss before showing the next one
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            entryToRecalculate = log
            showRecalculate = true
        }
    }

    private func handleRecalculateApply(_ updatedLog: FoodLog) {
        foodLogManager.updateLog(updatedLog)
        entryToRecalculate = nil
    }

    private func handleRecalculateKeep() {
        entryToRecalculate = nil
    }

    private func handleSwipeDelete(_ entry: FoodLog) {
        foodLogManager.deleteLog(entry)
    }
}

// MARK: - Previews

#Preview("Empty State") {
    FuelTabView()
}

#Preview("With Mock Data") {
    // Note: Previews won't show real data without setting up FoodLogManager
    FuelTabView()
}
