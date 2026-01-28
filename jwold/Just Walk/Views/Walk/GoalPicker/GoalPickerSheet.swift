//
//  GoalPickerSheet.swift
//  Just Walk
//
//  Main container sheet for the 3-step goal selection flow.
//  Flow: Goal Type Selection -> Value Selection -> Confirmation (Start/Route)
//

import SwiftUI
import CoreLocation

struct GoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var freeTierManager = FreeTierManager.shared
    @ObservedObject private var routeManager = RouteManager.shared
    @StateObject private var locationTracker = UserLocationTracker()

    // Flow state
    @State private var currentStep: GoalPickerStep = .selectType
    @State private var selectedGoalType: WalkGoalType = .time
    @State private var selectedValue: Double? = nil
    @State private var isCustom: Bool = false
    @State private var showCustomInput: Bool = false
    @State private var showRoutePreview: Bool = false
    @State private var isGeneratingRoute: Bool = false
    @State private var generatedRoute: RouteGenerator.GeneratedRoute?
    @State private var showUpsell: Bool = false

    // Callbacks
    var onStartWalk: (WalkGoal) -> Void = { _ in }
    var onStartWithRoute: (WalkGoal, RouteGenerator.GeneratedRoute) -> Void = { _, _ in }
    var onDismiss: () -> Void = {}
    var onShowPaywall: () -> Void = {}

    private enum GoalPickerStep {
        case selectType
        case selectValue
        case confirmation
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                    .padding(.top, 8)

                // Content based on step
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case .selectType:
                            typeSelectionContent
                        case .selectValue:
                            valueSelectionContent
                        case .confirmation:
                            confirmationContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(navigationTitle)
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarLeading) {
                    if currentStep != .selectType {
                        Button {
                            HapticService.shared.playSelection()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                goBack()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showCustomInput) {
            CustomGoalInputSheet(
                goalType: selectedGoalType,
                onSelect: { value in
                    selectedValue = value
                    isCustom = true
                    showCustomInput = false
                    advanceToConfirmation()
                },
                onDismiss: {
                    showCustomInput = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRoutePreview) {
            if let route = generatedRoute, let goal = buildGoal() {
                RoutePreviewSheet(
                    route: route,
                    goal: goal,
                    onStartWalk: {
                        showRoutePreview = false
                        dismiss()
                        onStartWithRoute(goal, route)
                    },
                    onTryAnother: {
                        showRoutePreview = false
                        generateRoute()
                    }
                )
            }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch currentStep {
        case .selectType: return "Set a Goal"
        case .selectValue: return selectedGoalType.label
        case .confirmation: return "Ready to Walk"
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(stepColor(for: index))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 40)
    }

    private func stepColor(for index: Int) -> Color {
        let currentIndex: Int
        switch currentStep {
        case .selectType: currentIndex = 0
        case .selectValue: currentIndex = 1
        case .confirmation: currentIndex = 2
        }

        return index <= currentIndex ? Color(hex: "00C7BE") : Color(.systemGray4)
    }

    // MARK: - Step 1: Type Selection

    private var typeSelectionContent: some View {
        VStack(spacing: 24) {
            Text("What kind of goal?")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            GoalTypeSelector(
                selectedType: $selectedGoalType,
                onSelect: { type in
                    selectedGoalType = type
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = .selectValue
                    }
                }
            )
        }
    }

    // MARK: - Step 2: Value Selection

    private var valueSelectionContent: some View {
        VStack(spacing: 24) {
            // Type tabs for quick switching
            GoalTypeSelector(
                selectedType: $selectedGoalType,
                onSelect: { type in
                    selectedGoalType = type
                    selectedValue = nil
                    isCustom = false
                }
            )

            GoalValueSelector(
                goalType: selectedGoalType,
                selectedValue: selectedValue,
                onSelectPreset: { value in
                    selectedValue = value
                    isCustom = false
                    advanceToConfirmation()
                },
                onSelectCustom: {
                    showCustomInput = true
                }
            )
        }
    }

    // MARK: - Step 3: Confirmation

    private var confirmationContent: some View {
        VStack(spacing: 24) {
            if let goal = buildGoal() {
                GoalConfirmationView(
                    goal: goal,
                    isPro: SubscriptionManager.shared.isPro,
                    canGenerateRoute: freeTierManager.canStartMagicRouteToday,
                    isGeneratingRoute: isGeneratingRoute,
                    onStartWalk: {
                        HapticService.shared.playIncrementMilestone()
                        dismiss()
                        onStartWalk(goal)
                    },
                    onGenerateRoute: {
                        generateRoute()
                    },
                    onChangeGoal: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep = .selectValue
                        }
                    },
                    onShowPaywall: {
                        onShowPaywall()
                    }
                )
            }
        }
    }

    // MARK: - Navigation Helpers

    private func goBack() {
        switch currentStep {
        case .selectType:
            break
        case .selectValue:
            currentStep = .selectType
        case .confirmation:
            currentStep = .selectValue
        }
    }

    private func advanceToConfirmation() {
        HapticService.shared.playSelection()
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = .confirmation
        }
    }

    // MARK: - Goal Building

    private func buildGoal() -> WalkGoal? {
        guard let value = selectedValue else { return nil }

        switch selectedGoalType {
        case .time:
            return .time(minutes: value, isCustom: isCustom)
        case .distance:
            return .distance(miles: value, isCustom: isCustom)
        case .steps:
            return .steps(count: value, isCustom: isCustom)
        case .none:
            return nil
        }
    }

    // MARK: - Route Generation

    private func generateRoute() {
        guard let goal = buildGoal() else { return }

        isGeneratingRoute = true

        let distanceMiles = WalkGoalPresets.estimatedDistance(for: goal)
        let location = locationTracker.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        Task {
            let route = await routeManager.generateRoute(distanceMiles: distanceMiles, from: location)

            await MainActor.run {
                isGeneratingRoute = false
                if let route = route {
                    generatedRoute = route
                    showRoutePreview = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GoalPickerSheet()
}
