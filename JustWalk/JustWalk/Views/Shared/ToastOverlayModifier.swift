//
//  ToastOverlayModifier.swift
//  JustWalk
//
//  ViewModifier that presents milestone toasts from the queue
//

import SwiftUI

struct ToastOverlayModifier: ViewModifier {
    @StateObject private var milestoneManager = MilestoneManager.shared
    @State private var currentToast: MilestoneEvent?
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = currentToast, isVisible {
                    MilestoneToastView(event: toast) {
                        dismissCurrent()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .zIndex(100)
                }
            }
            .onChange(of: milestoneManager.pendingToasts.count) { _, newCount in
                if newCount > 0 && currentToast == nil {
                    showNextToast()
                }
            }
            .onAppear {
                if !milestoneManager.pendingToasts.isEmpty && currentToast == nil {
                    showNextToast()
                }
            }
    }

    private func showNextToast() {
        guard let toast = milestoneManager.popNextToast() else { return }
        currentToast = toast

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = true
        }

        JustWalkHaptics.milestone()

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismissCurrent()
        }
    }

    private func dismissCurrent() {
        withAnimation(.easeIn(duration: 0.25)) {
            isVisible = false
        }

        // Brief delay before showing next toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            currentToast = nil
            if !milestoneManager.pendingToasts.isEmpty {
                showNextToast()
            }
        }
    }
}

extension View {
    func toastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}
