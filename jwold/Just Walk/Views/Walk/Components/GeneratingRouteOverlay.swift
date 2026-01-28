//
//  GeneratingRouteOverlay.swift
//  Just Walk
//
//  Created by Claude on 2026-01-22.
//

import SwiftUI

struct GeneratingRouteOverlay: View {
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Centered loading card
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Generating route...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

#Preview {
    ZStack {
        Color.blue
            .ignoresSafeArea()

        GeneratingRouteOverlay()
    }
}
