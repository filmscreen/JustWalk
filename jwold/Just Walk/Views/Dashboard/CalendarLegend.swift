//
//  CalendarLegend.swift
//  Just Walk
//
//  Minimal legend displayed below the streak calendar grid.
//  Shows what each day state means: Goal met, Missed, Protectable.
//

import SwiftUI

struct CalendarLegend: View {
    var onInfoTapped: () -> Void = {}

    var body: some View {
        HStack(spacing: 16) {
            legendItem(color: Color(hex: "00C7BE"), text: "Goal met")
            legendItem(color: Color(.systemGray4), text: "Missed")

            HStack(spacing: 4) {
                legendItem(color: Color(hex: "FF9500"), text: "Protectable", showPlus: true)

                Button {
                    onInfoTapped()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .padding(.trailing, -20)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, text: String, showPlus: Bool = false) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(showPlus ? 0.3 : 1.0))
                    .frame(width: 10, height: 10)

                if showPlus {
                    Circle()
                        .strokeBorder(color, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
            }

            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CalendarLegend()
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
}
