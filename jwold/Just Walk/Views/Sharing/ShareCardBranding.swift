//
//  ShareCardBranding.swift
//  Just Walk
//
//  Reusable branding component for share cards.
//  Shows app icon and "Just Walk" name for brand recognition.
//

import SwiftUI

struct ShareCardBranding: View {
    var style: BrandingStyle = .light

    enum BrandingStyle {
        case light  // White text on dark background
        case dark   // Dark text on light background
    }

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Image("AppIconShare")
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // App Name
            Text("Just Walk")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
        }
    }

    private var textColor: Color {
        switch style {
        case .light:
            return .white
        case .dark:
            return .primary
        }
    }
}

#Preview("Light Style") {
    ZStack {
        Color.black
        ShareCardBranding(style: .light)
    }
}

#Preview("Dark Style") {
    ZStack {
        Color.white
        ShareCardBranding(style: .dark)
    }
}
