//
//  StartWalkingButton.swift
//  Just Walk
//
//  Quick action button on the Today screen for starting a walk.
//

import SwiftUI

struct StartWalkingButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .semibold))
                Text("Just Walk")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(hex: "00C7BE"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Just Walk")
        .accessibilityHint("Navigates to Walk tab and starts a walk")
    }
}

#Preview {
    StartWalkingButton(onTap: {})
        .padding()
}
