//
//  WalkConfirmationView.swift
//  Just Walk
//
//  Screen 3: Confirmation before starting a walk.
//  Shows summary for Just Walk, phase breakdown for Fat Burn.
//

import SwiftUI

struct WalkConfirmationView: View {
    let walkType: WalkType
    let durationMinutes: Int

    @Environment(\.dismiss) private var dismiss
    @State private var showCountdown = false

    private var configuration: WalkConfiguration {
        WalkConfiguration(
            duration: TimeInterval(durationMinutes * 60),
            walkType: walkType
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Content based on walk type
                    if walkType == .fatBurn {
                        phaseBreakdown
                    } else {
                        simpleInfoCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)  // Space for button
            }

            // Start button (fixed at bottom)
            startButton
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCountdown) {
            PreWalkCountdownView(
                walkMode: walkType == .fatBurn ? .interval : .classic,
                onComplete: startWalk,
                onCancel: { showCountdown = false }
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(walkType.themeColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: walkType.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(walkType.themeColor)
            }

            // Name
            Text(walkType.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)

            // Duration
            Text("\(durationMinutes) min")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Simple Info Card (Just Walk)

    private var simpleInfoCard: some View {
        VStack(spacing: 8) {
            Text(walkType.formattedSteps(for: durationMinutes))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Text(walkType.description)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Phase Breakdown (Fat Burn)

    private var phaseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase Breakdown")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                let phases = configuration.generateFatBurnPhases()

                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    phaseRow(phase)

                    // Divider between rows (not after last)
                    if index < phases.count - 1 {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                    }
                }

                // Total row
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5)

                HStack {
                    Text("Total")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(configuration.formattedDuration)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func phaseRow(_ phase: IntervalPhaseInfo) -> some View {
        HStack(spacing: 12) {
            // Icon in colored circle
            ZStack {
                Circle()
                    .fill(phase.color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: phase.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(phase.color)
            }

            // Phase name
            Text(phase.name)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()

            // Duration
            Text(phase.formattedDuration)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    // MARK: - Start Button

    private var startButton: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                HapticService.shared.playSelection()
                showCountdown = true
            } label: {
                Text("Start Walk")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: "00C7BE"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func startWalk() {
        showCountdown = false

        // Configure IWTService based on walk type and duration
        let service = IWTService.shared
        service.sessionMode = walkType == .fatBurn ? .interval : .classic
        service.currentPhase = walkType == .fatBurn ? .warmup : .classic

        // TODO: Set duration-based configuration on IWTService
        // service.setConfiguration(from: configuration)

        // Post notification to trigger session view
        NotificationCenter.default.post(
            name: .remoteSessionStarted,
            object: nil,
            userInfo: ["mode": walkType == .fatBurn ? WalkMode.interval : WalkMode.classic]
        )
    }
}

// MARK: - Preview

#Preview("Just Walk") {
    NavigationStack {
        WalkConfirmationView(walkType: .justWalk, durationMinutes: 30)
    }
}

#Preview("Fat Burn") {
    NavigationStack {
        WalkConfirmationView(walkType: .fatBurn, durationMinutes: 30)
    }
}
