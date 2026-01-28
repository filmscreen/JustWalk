//
//  GlassPanel.swift
//  JustWalk
//
//  Reusable Liquid Glass panel container component
//

import SwiftUI

struct GlassPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding()
            .jwGlassEffect()
    }
}
