//
//  ContentView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI

/// Legacy content view - redirects to MainTabView
struct ContentView: View {
    var body: some View {
        AdaptiveNavigationContainer()
    }
}

// MARK: - Preview

#Preview("iPhone 16 Pro") {
    ContentView()
}

#Preview("iPhone 17 Pro Max") {
    ContentView()
}
