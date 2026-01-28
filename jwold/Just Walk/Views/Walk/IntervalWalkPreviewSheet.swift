//
//  IntervalWalkPreviewSheet.swift
//  Just Walk
//
//  Preview sheet showing the full Interval Walk structure (educational, no action button).
//

import SwiftUI

struct IntervalWalkPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Phase data based on IWTConfiguration.standard
    private let phases: [IntervalPhaseInfo] = IntervalPhaseInfo.standardPhases

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Scrollable phase list with total at bottom
                ScrollView {
                    VStack(spacing: 16) {
                        phaseList
                        totalRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Interval Walk")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Text("34 min total")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Phase List

    private var phaseList: some View {
        VStack(spacing: 0) {
            ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                phaseRow(phase)

                // Divider between rows (not after last)
                if index < phases.count - 1 {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                        .padding(.leading, 52)  // Align with text after icon
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func phaseRow(_ phase: IntervalPhaseInfo) -> some View {
        HStack(spacing: 12) {
            // Icon in colored circle
            ZStack {
                Circle()
                    .fill(phase.color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: phase.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(phase.color)
            }

            // Phase name
            Text(phase.name)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()

            // Duration
            Text(phase.formattedDuration)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    // MARK: - Total Row

    private var totalRow: some View {
        HStack {
            Text("Total")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text("34:00")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Phase Info Model

struct IntervalPhaseInfo: Identifiable {
    let id = UUID()
    let name: String
    let duration: TimeInterval  // seconds
    let color: Color
    let icon: String

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Standard 12-phase sequence based on IWTConfiguration.standard
    static var standardPhases: [IntervalPhaseInfo] {
        var phases: [IntervalPhaseInfo] = []

        // 1. Warm Up (2 min)
        phases.append(IntervalPhaseInfo(
            name: "Warm Up",
            duration: 120,
            color: Color(hex: "FF9500"),
            icon: "flame"
        ))

        // 2-11. Alternating Brisk/Recovery (5 cycles)
        for _ in 1...5 {
            // Brisk Walk (3 min)
            phases.append(IntervalPhaseInfo(
                name: "Brisk Walk",
                duration: 180,
                color: Color(hex: "FF3B30"),
                icon: "hare.fill"
            ))

            // Recovery Walk (3 min)
            phases.append(IntervalPhaseInfo(
                name: "Recovery Walk",
                duration: 180,
                color: Color(hex: "34C759"),
                icon: "tortoise.fill"
            ))
        }

        // 12. Cool Down (2 min)
        phases.append(IntervalPhaseInfo(
            name: "Cool Down",
            duration: 120,
            color: Color(hex: "007AFF"),
            icon: "snowflake"
        ))

        return phases
    }
}

// MARK: - Preview

#Preview {
    IntervalWalkPreviewSheet()
}
