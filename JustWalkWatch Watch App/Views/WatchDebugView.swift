//
//  WatchDebugView.swift
//  JustWalkWatch Watch App
//
//  Hidden debug view for previewing preset user profiles
//

import SwiftUI

struct WatchDebugProfile: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let steps: Int
    let goal: Int
    let streak: Int

    var summary: String {
        let pct = goal > 0 ? Int(Double(steps) / Double(goal) * 100) : 0
        return "\(pct)%, \(streak)d streak"
    }
}

extension WatchDebugProfile {
    static let presets: [WatchDebugProfile] = [
        WatchDebugProfile(name: "New User", icon: "person", steps: 0, goal: 5_000, streak: 0),
        WatchDebugProfile(name: "Morning Walk", icon: "sunrise", steps: 2_500, goal: 5_000, streak: 3),
        WatchDebugProfile(name: "Almost There", icon: "figure.walk", steps: 4_500, goal: 5_000, streak: 7),
        WatchDebugProfile(name: "Goal Crushed", icon: "trophy.fill", steps: 8_000, goal: 5_000, streak: 14),
        WatchDebugProfile(name: "Streak Legend", icon: "flame.fill", steps: 6_200, goal: 5_000, streak: 100),
        WatchDebugProfile(name: "Elite Walker", icon: "crown.fill", steps: 12_000, goal: 10_000, streak: 365),
    ]
}

struct WatchDebugView: View {
    var onSelect: (WatchDebugProfile) -> Void
    var onReset: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var subscriptionManager = WatchSubscriptionManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Tester Mode Toggle (works in production)
                Section("Pro Override") {
                    Toggle(isOn: Binding(
                        get: { subscriptionManager.isTesterModeEnabled },
                        set: { newValue in
                            if newValue {
                                subscriptionManager.enableTesterMode()
                            } else {
                                subscriptionManager.disableTesterMode()
                            }
                        }
                    )) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .frame(width: 20)
                            Text("Tester Mode")
                                .font(.caption.bold())
                        }
                    }
                    .tint(.green)
                }

                Section("Debug Profiles") {
                    ForEach(WatchDebugProfile.presets) { profile in
                        Button {
                            onSelect(profile)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: profile.icon)
                                    .foregroundStyle(.orange)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.caption.bold())
                                    Text(profile.summary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        onReset()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.red)
                                .frame(width: 20)
                            Text("Reset to Live")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        }
                    }
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink {
                        PhoneConnectivityTestView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text("Connectivity Test")
                                .font(.caption.bold())
                        }
                    }
                }
                #endif
            }
            .navigationTitle("Debug")
        }
    }
}

#Preview {
    WatchDebugView(onSelect: { _ in }, onReset: {})
}
