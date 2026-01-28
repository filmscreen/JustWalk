//
//  WatchDurationSelectionView.swift
//  Just Walk Watch App
//
//  Duration selection for Power Walk (18/30/42 min).
//

import SwiftUI
import WatchKit

struct WatchDurationSelectionView: View {
    let onSelect: (Int) -> Void
    let onCancel: () -> Void

    @ObservedObject private var healthManager = WatchHealthManager.shared

    private let durations = [18, 30, 42]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    Text("Power Walk")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "00C7BE"))

                    // Duration options
                    ForEach(durations, id: \.self) { minutes in
                        durationButton(minutes)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.gray)
                }
            }
        }
    }

    private func durationButton(_ minutes: Int) -> some View {
        let estimatedSteps = minutes * 120 // Average steps per minute

        return Button {
            WKInterfaceDevice.current().play(.click)
            onSelect(minutes)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(minutes) min")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("~\(estimatedSteps.formatted()) steps")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.darkGray).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    WatchDurationSelectionView(
        onSelect: { _ in },
        onCancel: {}
    )
}
