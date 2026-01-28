//
//  DebugOverlayView.swift
//  JustWalk
//
//  Quick-access floating debug panel for rapid persona switching
//

#if DEBUG
import SwiftUI

struct DebugOverlayView: View {
    @Binding var isPresented: Bool

    private var testDataProvider: TestDataProvider { TestDataProvider.shared }
    private var healthKitManager: HealthKitManager { HealthKitManager.shared }
    private var streakManager: StreakManager { StreakManager.shared }
    private var shieldManager: ShieldManager { ShieldManager.shared }

    @State private var selectedPersona: TestPersona = TestDataProvider.shared.activePersona

    var body: some View {
        ZStack {
            // Dismiss background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 16) {
                // Header
                HStack {
                    Label("Debug", systemImage: "ladybug.fill")
                        .font(.headline)

                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                // Warning banner
                if testDataProvider.isTestDataActive {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Test data active")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.15), in: Capsule())
                }

                // Live stats
                HStack(spacing: 16) {
                    statItem(label: "Steps", value: "\(healthKitManager.todaySteps)")
                    statItem(label: "Streak", value: "\(streakManager.streakData.currentStreak)")
                    statItem(label: "Shields", value: "\(shieldManager.shieldData.availableShields)")
                }

                Divider()

                // Milestones section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Milestones (\(MilestoneManager.shared.triggeredMilestones.count) triggered)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Tier 1") {
                            MilestoneManager.shared.debugTrigger(tier: .tier1)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)

                        Button("Tier 2") {
                            MilestoneManager.shared.debugTrigger(tier: .tier2)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button("Tier 3") {
                            MilestoneManager.shared.debugTrigger(tier: .tier3)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)

                        Spacer()

                        Button("Reset") {
                            MilestoneManager.shared.resetAllMilestones()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .font(.caption)
                }

                Divider()

                // Persona picker
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(TestPersona.allCases) { persona in
                            Button {
                                selectedPersona = persona
                                testDataProvider.applyPersona(persona)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: persona.icon)
                                        .frame(width: 22)

                                    Text(persona.displayName)
                                        .font(.subheadline)

                                    Spacer()

                                    if selectedPersona == persona {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    selectedPersona == persona
                                        ? Color.blue.opacity(0.1)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
            .padding(.horizontal, 24)
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
