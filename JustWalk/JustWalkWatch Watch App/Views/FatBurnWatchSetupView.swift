//
//  FatBurnWatchSetupView.swift
//  JustWalkWatch Watch App
//
//  Fat Burn Zone walk setup — calculates zone from HealthKit DOB on Watch
//

import SwiftUI

struct FatBurnWatchSetupView: View {
    @EnvironmentObject var appState: WatchAppState

    @State private var showCountdown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text("Walk in your fat-burning heart rate zone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Your zone is calculated from your age in Health.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Button {
                    showCountdown = true
                } label: {
                    Text("Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Fat Burn")
        .fullScreenCover(isPresented: $showCountdown) {
            WatchCountdownView {
                appState.startFatBurnWalk()
            }
        }
    }
}

#Preview {
    NavigationStack {
        FatBurnWatchSetupView()
            .environmentObject(WatchAppState())
    }
}
