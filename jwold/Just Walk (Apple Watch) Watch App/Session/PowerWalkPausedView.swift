//
//  PowerWalkPausedView.swift
//  Just Walk Watch App
//
//  Paused state for Power Walk intervals.
//

import SwiftUI
import WatchKit

struct PowerWalkPausedView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @State private var showEndConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Paused indicator
            VStack(spacing: 8) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)

                Text("Paused")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                // Current phase info
                Text("\(sessionManager.currentPhase.title) - \(sessionManager.formattedTime) left")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))

                // Steps
                Text("\(sessionManager.sessionSteps) steps")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Resume/End buttons
            HStack(spacing: 16) {
                // Resume Button
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
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
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
                        .frame(width: 52)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .confirmationDialog("End workout early?", isPresented: $showEndConfirmation) {
            Button("End Workout", role: .destructive) {
                sessionManager.stopSession()
            }
            Button("Keep Paused", role: .cancel) {}
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.orange.opacity(0.5)
            .ignoresSafeArea()

        PowerWalkPausedView()
    }
}
