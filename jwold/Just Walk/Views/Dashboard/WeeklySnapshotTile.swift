//
//  WeeklySnapshotTile.swift
//  Just Walk
//
//  Persistent tile on Dashboard showing weekly recap is available.
//  Stays until user explicitly dismisses with X button.
//

import SwiftUI

struct WeeklySnapshotTile: View {
    let snapshot: WeeklySnapshot
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: JWDesign.Spacing.md) {
                // Trophy icon
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                        .symbolEffect(.pulse, options: .repeating)
                }

                // Text
                VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                    Text("Weekly Recap Ready")
                        .font(JWDesign.Typography.subheadlineBold)
                        .foregroundStyle(.primary)
                    Text("\(snapshot.formattedSteps) steps last week")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Dismiss button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(JWDesign.Spacing.md)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: JWDesign.Radius.card)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WeeklySnapshotTile(
        snapshot: WeeklySnapshot(
            weekStartDate: Date(),
            weekEndDate: Date(),
            totalSteps: 72345,
            percentageChange: 12,
            bestDayName: "Saturday",
            bestDaySteps: 14523,
            totalMiles: 36
        ),
        onTap: {},
        onDismiss: {}
    )
    .padding()
}
