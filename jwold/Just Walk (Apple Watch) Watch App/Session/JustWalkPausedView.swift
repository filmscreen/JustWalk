//
//  JustWalkPausedView.swift
//  Just Walk Watch App
//
//  Paused state view with Resume and End options.
//

import SwiftUI
import WatchKit

struct JustWalkPausedView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @State private var showEndConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Paused indicator
            VStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Paused")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                // Session steps while paused
                Text("\(sessionManager.sessionSteps) steps")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                // Elapsed time while paused
                if let startTime = sessionManager.sessionStartTime {
                    Text(startTime, style: .timer)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }

            Spacer()

            // Resume/End buttons
            HStack(spacing: 8) {
                // Resume Button - uses teal to match brand
                Button {
                    WKInterfaceDevice.current().play(.start)
                    sessionManager.resumeSession()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Resume")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "00C7BE"))  // Teal
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // End Button
                Button {
                    showEndConfirmation = true
                } label: {
                    Text("End")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .confirmationDialog("End walk?", isPresented: $showEndConfirmation) {
            Button("End Walk", role: .destructive) {
                sessionManager.stopSession()
            }
            Button("Keep Paused", role: .cancel) {}
        }
    }
}

// MARK: - Preview

#Preview {
    JustWalkPausedView()
}
