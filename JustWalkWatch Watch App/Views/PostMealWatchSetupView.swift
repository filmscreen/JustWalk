//
//  PostMealWatchSetupView.swift
//  JustWalkWatch Watch App
//
//  Post-Meal walk setup — simple 10-minute walk, works standalone
//

import SwiftUI

struct PostMealWatchSetupView: View {
    @EnvironmentObject var appState: WatchAppState

    @State private var showCountdown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("A short walk after eating helps manage blood sugar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showCountdown = true
                } label: {
                    Text("Start 10 min")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .tint(.orange)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Post-Meal")
        .fullScreenCover(isPresented: $showCountdown) {
            WatchCountdownView {
                appState.startWalk(mode: .postMeal)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PostMealWatchSetupView()
            .environmentObject(WatchAppState())
    }
}
