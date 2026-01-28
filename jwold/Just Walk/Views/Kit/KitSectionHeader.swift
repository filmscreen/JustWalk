//
//  KitSectionHeader.swift
//  Just Walk
//
//  Section header for the Kit tab.
//

import SwiftUI

struct KitSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: JWDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: JWDesign.IconSize.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                Text(title)
                    .font(JWDesign.Typography.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, JWDesign.Spacing.sm)
    }
}

#Preview {
    VStack {
        KitSectionHeader(title: "Footwear", subtitle: "Maintenance", icon: "shoe.fill")
        KitSectionHeader(title: "WFH", subtitle: "Environment", icon: "desktopcomputer")
        KitSectionHeader(title: "Intensity", subtitle: "Level Up", icon: "flame.fill")
    }
    .padding()
}
