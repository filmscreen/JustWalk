//
//  PhoneConnectionIndicator.swift
//  JustWalkWatch Watch App
//
//  Shows iPhone connection status on the Watch idle screen
//

import SwiftUI

struct PhoneConnectionIndicator: View {
    @ObservedObject private var connectivity = WatchConnectivityManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectivity.isPhoneReachable ? .green : .orange)
                .frame(width: 6, height: 6)

            Text(connectivity.isPhoneReachable ? "iPhone Connected" : "iPhone Not Reachable")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PhoneConnectionIndicator()
}
