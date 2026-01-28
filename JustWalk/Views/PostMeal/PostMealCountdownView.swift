//
//  PostMealCountdownView.swift
//  JustWalk
//
//  Container for the post-meal walk flow:
//  CountdownView -> PostMealActiveView -> PostMealCompletionView
//

import SwiftUI

struct PostMealCountdownView: View {
    var onFlowComplete: () -> Void

    @StateObject private var walkSession = WalkSessionManager.shared
    @State private var showCountdown = true
    @State private var showCompletion = false

    var body: some View {
        ZStack {
            if showCountdown {
                CountdownView {
                    startPostMealWalk()
                    showCountdown = false
                }
                .transition(.opacity)
            } else if showCompletion, let walk = walkSession.completedWalk {
                PostMealCompletionView(walk: walk) {
                    onFlowComplete()
                }
                .transition(.scaleUp)
            } else {
                PostMealActiveView()
                    .transition(.slideUp)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showCountdown)
        .animation(.easeInOut(duration: 0.3), value: showCompletion)
        .navigationBarBackButtonHidden(true)
        .onChange(of: walkSession.completedWalk != nil) { _, hasWalk in
            if hasWalk && walkSession.completedWalk?.mode == .postMeal {
                // Save walk to persistence
                if let walk = walkSession.completedWalk {
                    PersistenceManager.shared.saveTrackedWalk(walk)
                }
                showCompletion = true
            }
        }
    }

    private func startPostMealWalk() {
        walkSession.startWalk(mode: .postMeal)
    }
}

#Preview {
    NavigationStack {
        PostMealCountdownView(onFlowComplete: {})
    }
}
