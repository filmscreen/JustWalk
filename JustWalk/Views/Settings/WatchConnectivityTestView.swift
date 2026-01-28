//
//  WatchConnectivityTestView.swift
//  JustWalk
//
//  DEBUG-only test view for verifying Watch connectivity
//

#if DEBUG

import SwiftUI
import WatchConnectivity

struct WatchConnectivityTestView: View {
    @ObservedObject private var connectivity = PhoneConnectivityManager.shared
    @State private var messageLog: [LogEntry] = []
    @State private var testWalkId = UUID()

    var body: some View {
        List {
            // MARK: - Connection Status
            Section("Connection Status") {
                statusRow("WCSession Supported", value: WCSession.isSupported() ? "Yes" : "No", color: WCSession.isSupported() ? .green : .red)
                statusRow("Watch Paired", value: connectivity.canCommunicateWithWatch ? "Yes" : "No", color: connectivity.canCommunicateWithWatch ? .green : .red)
                statusRow("Watch App Installed", value: connectivity.isWatchAppInstalled ? "Yes" : "No", color: connectivity.isWatchAppInstalled ? .green : .orange)
                statusRow("Watch Reachable", value: connectivity.isWatchReachable ? "Yes" : "No", color: connectivity.isWatchReachable ? .green : .orange)
                statusRow("Immediately Reachable", value: connectivity.isWatchImmediatelyReachable ? "Yes" : "No", color: connectivity.isWatchImmediatelyReachable ? .green : .orange)
                statusRow("Workout State", value: connectivity.watchWorkoutState.displayName, color: .blue)
            }

            // MARK: - Test Actions
            Section("Test Actions") {
                Button {
                    sendPing()
                } label: {
                    Label("Send Ping", systemImage: "antenna.radiowaves.left.and.right")
                }

                Button {
                    sendTestWorkoutStart()
                } label: {
                    Label("Send Start Workout", systemImage: "play.fill")
                }

                Button {
                    sendTestWorkoutEnd()
                } label: {
                    Label("Send End Workout", systemImage: "stop.fill")
                }

                Button {
                    sendTestPause()
                } label: {
                    Label("Send Pause", systemImage: "pause.fill")
                }

                Button {
                    sendTestResume()
                } label: {
                    Label("Send Resume", systemImage: "play.fill")
                }
            }

            // MARK: - Message Log
            Section("Message Log") {
                if messageLog.isEmpty {
                    Text("No messages yet")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(messageLog) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: entry.isOutgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .foregroundStyle(entry.isOutgoing ? .blue : .green)
                                    .font(.caption)
                                Text(entry.title)
                                    .font(.caption.bold())
                            }
                            Text(entry.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(entry.timestamp.formatted(.dateTime.hour().minute().second()))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                if !messageLog.isEmpty {
                    Button("Clear Log", role: .destructive) {
                        messageLog.removeAll()
                    }
                }
            }
        }
        .navigationTitle("Watch Connectivity")
        .onAppear {
            setupCallbacks()
        }
    }

    // MARK: - Status Row

    private func statusRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
    }

    // MARK: - Actions

    private func sendPing() {
        let start = Date()
        log(title: "Ping Sent", detail: "Checking reachability...", outgoing: true)

        connectivity.startWorkoutOnWatch(walkId: UUID()) { success in
            let elapsed = Date().timeIntervalSince(start)
            log(
                title: success ? "Ping Success" : "Ping Failed",
                detail: String(format: "Round-trip: %.0fms", elapsed * 1000),
                outgoing: false
            )
        }
    }

    private func sendTestWorkoutStart() {
        testWalkId = UUID()
        log(title: "Start Workout", detail: "Walk ID: \(testWalkId.uuidString.prefix(8))...", outgoing: true)

        let testInterval = IntervalTransferData(
            programName: "Test Quick",
            totalDurationSeconds: 120,
            phases: [
                IntervalPhaseData(type: "warmup", durationSeconds: 30, startOffset: 0),
                IntervalPhaseData(type: "fast", durationSeconds: 30, startOffset: 30),
                IntervalPhaseData(type: "slow", durationSeconds: 30, startOffset: 60),
                IntervalPhaseData(type: "cooldown", durationSeconds: 30, startOffset: 90)
            ]
        )

        connectivity.startWorkoutOnWatch(walkId: testWalkId, intervalData: testInterval) { success in
            log(
                title: success ? "Start Sent" : "Start Failed",
                detail: "Interval data included",
                outgoing: false
            )
        }
    }

    private func sendTestWorkoutEnd() {
        log(title: "End Workout", detail: "Walk ID: \(testWalkId.uuidString.prefix(8))...", outgoing: true)
        connectivity.endWorkoutOnWatch { success in
            log(
                title: success ? "End Sent" : "End Failed",
                detail: "",
                outgoing: false
            )
        }
    }

    private func sendTestPause() {
        log(title: "Pause Workout", detail: "", outgoing: true)
        connectivity.pauseWorkoutOnWatch()
    }

    private func sendTestResume() {
        log(title: "Resume Workout", detail: "", outgoing: true)
        connectivity.resumeWorkoutOnWatch()
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        connectivity.onWorkoutStartedOnWatch = { walkId in
            log(title: "Watch: Workout Started", detail: "Walk ID: \(walkId.uuidString.prefix(8))...", outgoing: false)
        }

        connectivity.onWorkoutEndedOnWatch = { summary in
            log(
                title: "Watch: Workout Ended",
                detail: "Steps: \(summary.totalSteps), Duration: \(summary.totalSeconds)s",
                outgoing: false
            )
        }

        connectivity.onWatchError = { error in
            log(title: "Watch: Error", detail: error, outgoing: false)
        }
    }

    // MARK: - Logging

    private func log(title: String, detail: String, outgoing: Bool) {
        DispatchQueue.main.async {
            let entry = LogEntry(title: title, detail: detail, isOutgoing: outgoing)
            messageLog.insert(entry, at: 0)
            // Keep log manageable
            if messageLog.count > 50 {
                messageLog = Array(messageLog.prefix(50))
            }
        }
    }
}

// MARK: - Log Entry

private struct LogEntry: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isOutgoing: Bool
    let timestamp = Date()
}

// MARK: - WorkoutState Display

private extension WorkoutState {
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .active: return "Active"
        case .paused: return "Paused"
        case .ending: return "Ending"
        }
    }
}

#Preview {
    NavigationStack {
        WatchConnectivityTestView()
    }
}

#endif
