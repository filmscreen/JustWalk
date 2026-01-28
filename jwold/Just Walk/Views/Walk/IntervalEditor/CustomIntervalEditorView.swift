//
//  CustomIntervalEditorView.swift
//  Just Walk
//
//  Main editor screen for creating custom Power Walk interval configurations.
//  Pro-only feature allowing precise control over easy/brisk durations.
//

import SwiftUI
import Combine

/// Main editor view for custom interval configurations
struct CustomIntervalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = IntervalEditorViewModel()
    @EnvironmentObject private var storeManager: StoreManager

    @State private var showSaveSheet = false
    @State private var showPaywall = false

    /// Callback when user starts workout with custom configuration
    let onStartWorkout: (IWTConfiguration) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                JWDesign.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: JWDesign.Spacing.lg) {
                            // Header section
                            headerSection

                            // Duration pickers
                            durationPickersSection

                            // Number of intervals
                            intervalCountSection

                            // Warmup/Cooldown toggles
                            phaseTogglesSection

                            // Live preview
                            WorkoutSummaryCard(
                                totalDuration: viewModel.formattedTotalDuration,
                                estimatedSteps: viewModel.formattedEstimatedSteps,
                                numberOfCycles: viewModel.numberOfIntervals,
                                workoutDescription: viewModel.workoutDescription
                            )

                            // Visual timeline
                            IntervalTimelinePreview(
                                easyDuration: viewModel.easyDurationSeconds,
                                briskDuration: viewModel.briskDurationSeconds,
                                numberOfIntervals: viewModel.numberOfIntervals,
                                includeWarmup: viewModel.includeWarmup,
                                includeCooldown: viewModel.includeCooldown
                            )

                            // Validation banner
                            if let error = viewModel.validationError,
                               case .durationTooShort = error {
                                validationBanner(error)
                            } else if let error = viewModel.validationError,
                                      case .durationTooLong = error {
                                validationBanner(error)
                            }

                            // Spacing for bottom buttons
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, JWDesign.Spacing.md)
                        .padding(.top, JWDesign.Spacing.md)
                    }

                    // Fixed bottom buttons
                    actionButtonsSection
                }
            }
            .navigationTitle("Custom Intervals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .sheet(isPresented: $showSaveSheet) {
                SavePresetSheet(viewModel: viewModel) {
                    // Preset saved successfully
                }
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
            // NOTE: Paywall check removed - now handled by PowerWalkSetupView gear button
            // The double paywall bug was caused by showing paywall both here AND in the parent view
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            // Pro badge + icon
            HStack(spacing: JWDesign.Spacing.sm) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(JWDesign.Colors.brandSecondary)

                ProBadge()
            }

            Text("Customize Your Walk")
                .font(JWDesign.Typography.displaySmall)
                .foregroundStyle(.primary)

            Text("Customize intervals to match your fitness level")
                .font(JWDesign.Typography.body)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, JWDesign.Spacing.md)
    }

    private var durationPickersSection: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            // Easy duration picker
            IntervalDurationPicker(
                title: "Easy Duration",
                subtitle: "Comfortable walking pace",
                icon: "tortoise.fill",
                iconColor: JWDesign.Colors.success,
                selectedDuration: viewModel.easyDurationSeconds,
                options: viewModel.durationOptions
            ) { duration in
                viewModel.setEasyDuration(duration)
            }

            // Brisk duration picker
            IntervalDurationPicker(
                title: "Brisk Duration",
                subtitle: "Faster power walking pace",
                icon: "hare.fill",
                iconColor: JWDesign.Colors.brandSecondary,
                selectedDuration: viewModel.briskDurationSeconds,
                options: viewModel.durationOptions
            ) { duration in
                viewModel.setBriskDuration(duration)
            }
        }
    }

    private var intervalCountSection: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            HStack {
                Text("Number of Intervals")
                    .font(JWDesign.Typography.bodyBold)
                    .foregroundStyle(.primary)

                Spacer()
            }

            HStack(spacing: JWDesign.Spacing.lg) {
                // Decrement button
                Button {
                    viewModel.setIntervalCount(viewModel.numberOfIntervals - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            viewModel.numberOfIntervals > IntervalEditorViewModel.minIntervals
                            ? JWDesign.Colors.brandSecondary
                            : Color(.tertiaryLabel)
                        )
                }
                .disabled(viewModel.numberOfIntervals <= IntervalEditorViewModel.minIntervals)

                // Count display
                VStack(spacing: 2) {
                    Text("\(viewModel.numberOfIntervals)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("intervals")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(Color(.secondaryLabel))

                    Text("Easy + Brisk")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .frame(minWidth: 80)

                // Increment button
                Button {
                    viewModel.setIntervalCount(viewModel.numberOfIntervals + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            viewModel.numberOfIntervals < IntervalEditorViewModel.maxIntervals
                            ? JWDesign.Colors.brandSecondary
                            : Color(.tertiaryLabel)
                        )
                }
                .disabled(viewModel.numberOfIntervals >= IntervalEditorViewModel.maxIntervals)
            }
            .animation(JWDesign.Animation.spring, value: viewModel.numberOfIntervals)
        }
        .padding(JWDesign.Spacing.md)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }

    private var phaseTogglesSection: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            // Warmup toggle
            Toggle(isOn: Binding(
                get: { viewModel.includeWarmup },
                set: { viewModel.setIncludeWarmup($0) }
            )) {
                HStack(spacing: JWDesign.Spacing.sm) {
                    Image(systemName: "figure.walk.motion")
                        .foregroundStyle(Color(.secondaryLabel))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Warm Up")
                            .font(JWDesign.Typography.bodyBold)
                            .foregroundStyle(.primary)

                        Text("2 min easy pace")
                            .font(JWDesign.Typography.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
            .tint(JWDesign.Colors.brandSecondary)

            Divider()

            // Cooldown toggle
            Toggle(isOn: Binding(
                get: { viewModel.includeCooldown },
                set: { viewModel.setIncludeCooldown($0) }
            )) {
                HStack(spacing: JWDesign.Spacing.sm) {
                    Image(systemName: "wind")
                        .foregroundStyle(Color(.secondaryLabel))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cool Down")
                            .font(JWDesign.Typography.bodyBold)
                            .foregroundStyle(.primary)

                        Text("2 min easy pace")
                            .font(JWDesign.Typography.caption)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
            .tint(JWDesign.Colors.brandSecondary)
        }
        .padding(JWDesign.Spacing.md)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }

    private func validationBanner(_ error: IntervalEditorViewModel.ValidationError) -> some View {
        HStack(spacing: JWDesign.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(JWDesign.Colors.warning)

            Text(error.localizedDescription)
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(JWDesign.Spacing.md)
        .background(JWDesign.Colors.warning.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.small))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var actionButtonsSection: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            Divider()

            HStack(spacing: JWDesign.Spacing.md) {
                // Save button (secondary)
                Button {
                    if viewModel.canSaveMorePresets {
                        showSaveSheet = true
                    } else {
                        viewModel.validationError = .maxCustomPresetsReached
                        HapticService.shared.playError()
                    }
                } label: {
                    Text("Save")
                        .font(JWDesign.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, JWDesign.Spacing.md)
                }
                .buttonStyle(JWSecondaryButtonStyle())
                .disabled(!viewModel.isValidConfiguration)
                .opacity(viewModel.isValidConfiguration ? 1 : 0.5)

                // Start workout button (primary)
                Button {
                    let config = viewModel.buildConfiguration()
                    HapticService.shared.playSymphony()
                    onStartWorkout(config)
                    dismiss()
                } label: {
                    Text("Start Walk")
                        .font(JWDesign.Typography.headlineBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, JWDesign.Spacing.md)
                }
                .buttonStyle(JWGradientButtonStyle())
                .disabled(!viewModel.isValidConfiguration)
                .opacity(viewModel.isValidConfiguration ? 1 : 0.5)
            }
            .padding(.horizontal, JWDesign.Spacing.md)
            .padding(.bottom, JWDesign.Spacing.md)
        }
        .background(JWDesign.Colors.background)
    }
}

// MARK: - Pro Badge

/// Small Pro badge indicator
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [JWDesign.Colors.brandSecondary, JWDesign.Colors.brandSecondary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("Custom Interval Editor") {
    CustomIntervalEditorView { config in
        print("Start workout with config: \(config)")
    }
    .environmentObject(StoreManager.shared)
}
