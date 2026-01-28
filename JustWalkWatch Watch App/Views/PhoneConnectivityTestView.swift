//
//  PhoneConnectivityTestView.swift
//  JustWalkWatch Watch App
//
//  DEBUG-only test view for verifying iPhone connectivity from Watch
//

#if DEBUG

import SwiftUI
import WatchConnectivity

struct PhoneConnectivityTestView: View {
    @ObservedObject private var connectivity = WatchConnectivityManager.shared
    @State private var messageLog: [WatchLogEntry] = []

    var body: some View {
        List {
            // MARK: - Status
            Section("Status") {
                HStack {
                    Text("iPhone Reachable")
                    Spacer()
                    Image(systemName: connectivity.isPhoneReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(connectivity.isPhoneReachable ? .green : .red)
                }

                HStack {
                    Text("Session Active")
                    Spacer()
                    Image(systemName: WCSession.default.activationState == .activated ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(WCSession.default.activationState == .activated ? .green : .red)
                }
            }

            // MARK: - Test Actions
            Section("Actions") {
                Button {
                    sendTestEvent()
                } label: {
                    Label("Send Test Event", systemImage: "paperplane.fill")
                }

                Button {
                    sendTestStats()
                } label: {
                    Label("Send Stats Update", systemImage: "chart.bar.fill")
                }
            }

            // MARK: - Log
            Section("Log") {
                if messageLog.isEmpty {
                    Text("No messages")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                } else {
                    ForEach(messageLog) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.caption2.bold())
                            Text(entry.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !messageLog.isEmpty {
                    Button("Clear", role: .destructive) {
                        messageLog.removeAll()
                    }
                }
            }
        }
        .navigationTitle("Connectivity")
    }

    private func sendTestEvent() {
        let walkId = UUID()
        connectivity.sendWorkoutStarted(walkId: walkId)
        log(title: "Sent: workoutStarted", detail: "ID: \(walkId.uuidString.prefix(8))...")
    }

    private func sendTestStats() {
        let stats = WorkoutLiveStats(
            walkId: UUID(),
            elapsedSeconds: 120,
            heartRate: 105,
            steps: 250,
            activeCalories: 45,
            distance: 200,
            timestamp: Date()
        )
        connectivity.sendStatsUpdate(stats: stats)
        log(title: "Sent: statsUpdate", detail: "Steps: 250, HR: 105")
    }

    private func log(title: String, detail: String) {
        messageLog.insert(WatchLogEntry(title: title, detail: detail), at: 0)
        if messageLog.count > 20 {
            messageLog = Array(messageLog.prefix(20))
        }
    }
}

private struct WatchLogEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

#Preview {
    PhoneConnectivityTestView()
}

#endif
