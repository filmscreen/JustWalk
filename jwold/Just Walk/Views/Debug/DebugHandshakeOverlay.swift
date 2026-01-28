//
//  DebugHandshakeOverlay.swift
//  Just Walk
//
//  Debug overlay for step counting diagnostics.
//  Tap the progress ring 3 times to show this overlay.
//
//  Shows HealthKit-based step data (single source of truth).
//

#if DEBUG
import SwiftUI

struct DebugHandshakeOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject var stepRepo = StepRepository.shared
    var onShieldYesterday: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        isPresented = false
                    }
                }

            // Debug card
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Image(systemName: "ant.fill")
                            .foregroundStyle(.orange)
                        Text("Step Diagnosis")
                            .font(.headline)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.title2)
                        }
                    }

                    // SECTION 1: Display Value
                    SectionHeader(title: "TODAY'S STEPS", icon: "figure.walk")

                    VStack(spacing: 4) {
                        Text("\(stepRepo.todaySteps.formatted())")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Source: HealthKit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    // SECTION 2: HealthKit Details
                    SectionHeader(title: "HEALTHKIT DATA", icon: "heart.fill")

                    VStack(spacing: 6) {
                        AlgorithmRow(label: "HealthKit Steps", value: "\(stepRepo.healthKitSteps.formatted())")
                        AlgorithmRow(label: "Distance", value: String(format: "%.0f m", stepRepo.todayDistance))
                        AlgorithmRow(label: "Goal", value: "\(stepRepo.stepGoal.formatted())")
                        AlgorithmRow(label: "Progress", value: String(format: "%.0f%%", stepRepo.goalProgress * 100))
                    }

                    // SECTION 3: Sync Status
                    SectionHeader(title: "SYNC STATUS", icon: "arrow.triangle.2.circlepath")

                    VStack(spacing: 6) {
                        AlgorithmRow(label: "Last Refresh", value: lastSyncFormatted)
                        AlgorithmRow(label: "Method", value: "HKStatisticsQuery (.cumulativeSum)")
                    }

                    // Status indicator
                    HStack {
                        Circle()
                            .fill(stepRepo.todaySteps > 0 ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(stepRepo.todaySteps > 0 ? "Active" : "No Data")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("Apple handles deduplication")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)

                    // Architecture note
                    Text("HealthKit is the single source of truth. iPhone + Watch data is automatically deduplicated by Apple.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)

                    // Debug Actions
                    Divider()
                        .padding(.vertical, 8)

                    SectionHeader(title: "TEST SCENARIOS", icon: "flask.fill")

                    // Test scenario picker
                    VStack(spacing: 6) {
                        ForEach(TestScenario.allCases, id: \.rawValue) { scenario in
                            TestScenarioButton(
                                scenario: scenario,
                                isSelected: TestDataProvider.shared.currentScenario == scenario,
                                onSelect: {
                                    TestDataProvider.shared.setScenario(scenario)
                                }
                            )
                        }
                    }

                    if TestDataProvider.shared.isTestDataEnabled {
                        Text("⚠️ Using test data. Tap 'Real Data' to return to HealthKit.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.top, 4)
                    }

                    if onShieldYesterday != nil {
                        Divider()
                            .padding(.vertical, 8)

                        SectionHeader(title: "DEBUG ACTIONS", icon: "hammer.fill")

                        Button {
                            onShieldYesterday?()
                        } label: {
                            HStack {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(.mint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Toggle Shield + 5K Steps")
                                        .font(.caption)
                                    Text("Applies to yesterday")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxHeight: 400)
            .padding(24)
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: - Computed Properties

    private var lastSyncFormatted: String {
        if stepRepo.lastHealthKitRefresh == .distantPast {
            return "Never"
        }
        let interval = Date().timeIntervalSince(stepRepo.lastHealthKitRefresh)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return stepRepo.lastHealthKitRefresh.formatted(date: .omitted, time: .shortened)
        }
    }
}

// MARK: - Helper Views

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption.bold())
        }
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }
}

private struct AlgorithmRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }
}

private struct TestScenarioButton: View {
    let scenario: TestScenario
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scenario.displayName)
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text(scenarioDescription)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isSelected ? Color.green.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var scenarioDescription: String {
        switch scenario {
        case .realData:
            return "HealthKit data"
        case .newUser:
            return "0 steps, no history"
        case .midDay:
            return "4,500 steps, 3-day streak"
        case .streakAtRisk:
            return "8,200 steps, 14-day streak"
        case .goalCrushed:
            return "12,400 steps, goal met"
        case .streakLost:
            return "1,200 steps, streak broken"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DebugHandshakeOverlay(isPresented: .constant(true))
    }
}
#endif
