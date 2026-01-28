//
//  OptionChip.swift
//  Just Walk
//
//  Created by Claude on 2026-01-22.
//

import SwiftUI

struct OptionChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.shared.playSelection()
            action()
        }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color(hex: "00C7BE") : Color.gray.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            OptionChip(label: "1 mi", isSelected: true) {}
            OptionChip(label: "2 mi", isSelected: false) {}
            OptionChip(label: "3 mi", isSelected: false) {}
        }

        HStack(spacing: 12) {
            OptionChip(label: "15 min", isSelected: false) {}
            OptionChip(label: "30 min", isSelected: true) {}
            OptionChip(label: "45 min", isSelected: false) {}
        }
    }
    .padding()
}
