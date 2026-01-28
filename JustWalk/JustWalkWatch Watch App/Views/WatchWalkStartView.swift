//
//  WatchWalkStartView.swift
//  JustWalkWatch Watch App
//
//  Walk start screen with Just Walk + interval program options
//

import SwiftUI
import WatchKit

struct WatchWalkStartView: View {
    @Bindable var session: WatchWalkSessionManager
    var onWalkStarted: (() -> Void)? = nil
    @State private var subscription = WatchSubscriptionManager.shared
    @State private var showProAlert = false
    
    @State private var showCountdown = false
    @State private var pendingInterval: WatchIntervalProgram? = nil
    @State private var testerTapCount = 0

    private static let brandGreen = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header - tap 10 times to unlock tester mode
                HStack(spacing: 4) {
                    Text("Interval Walks")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !subscription.isPro {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(subscription.isPro ? "Interval Walks" : "Interval Walks, locked, requires Pro")
                .onTapGesture {
                    testerTapCount += 1
                    if testerTapCount >= 10 {
                        testerTapCount = 0
                        if subscription.isTesterModeEnabled {
                            subscription.disableTesterMode()
                        } else {
                            subscription.enableTesterMode()
                        }
                        WKInterfaceDevice.current().play(.success)
                    }
                }

                ForEach(WatchIntervalProgram.allCases) { program in
                    Button {
                        if subscription.isPro {
                            // Show countdown before starting
                            pendingInterval = program
                            showCountdown = true
                        } else {
                            showProAlert = true
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(program.displayName)
                                    .font(.caption.bold())
                                Text("\(program.durationMinutes) min")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !subscription.isPro {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(program.displayName), \(program.durationMinutes) minutes")
                    .accessibilityHint(subscription.isPro ? "Start \(program.displayName) interval walk" : "Locked, requires JustWalk Pro")
                }

                if !subscription.isPro {
                    Label("Unlock with Pro", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)
        }
        .alert("Pro Required", isPresented: $showProAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Intervals are a Pro feature. Open JustWalk on your iPhone to subscribe. Already a member? It may take a moment to sync.")
        }
        .fullScreenCover(isPresented: $showCountdown) {
            WatchCountdownView {
                // Countdown complete — start the walk
                if let program = pendingInterval {
                    session.startWalk(interval: program)
                    pendingInterval = nil
                    onWalkStarted?()
                }
            }
        }
        .task {
            await subscription.checkProStatus()
        }
    }
}

