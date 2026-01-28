//
//  GlassButton.swift
//  JustWalk
//
//  Reusable Liquid Glass button component
//

import SwiftUI

struct GlassButton: View {
    let title: String
    let icon: String?
    let tint: Color?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, tint: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(JW.Font.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .jwGlassEffect(tintColor: tint)
        .buttonPressEffect()
    }
}
