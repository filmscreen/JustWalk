//
//  MilestonesRow.swift
//  Just Walk
//
//  Horizontal row showing streak milestones with progress indicators.
//

import SwiftUI

struct MilestonesRow: View {
    let currentStreak: Int
    var streakStartDate: Date? = nil

    // Standard milestones (show all)
    private let milestones = [7, 14, 30, 60, 100]

    // Toast state for showing achievement date
    @State private var showingToast = false
    @State private var toastMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {  // 12pt section spacing
            // Section header - 13pt semibold uppercase tertiary
            Text("MILESTONES")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
                .tracking(0.5)

            // Milestone chips - horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {  // 12pt between badges
                    ForEach(milestones, id: \.self) { milestone in
                        milestoneChip(milestone)
                    }
                }
                .padding(.horizontal, 16)  // 16pt leading/trailing
            }

            // Achievement toast overlay
            if showingToast {
                Text(toastMessage)
                    .font(.system(size: 13, weight: .regular))  // 13pt caption
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: "00C7BE"))
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)  // 16pt all sides
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    // MARK: - Milestone Chip

    @ViewBuilder
    private func milestoneChip(_ milestone: Int) -> some View {
        let isAchieved = currentStreak >= milestone
        let isNext = milestone == (milestones.first(where: { $0 > currentStreak }) ?? 0)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {  // 8pt icon-to-text spacing
                // Icon - 14pt
                if isAchieved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isNext ? Color(hex: "00C7BE") : Color(hex: "D1D1D6"))
                }

                // Label
                Text(milestoneLabel(milestone))
                    .font(.system(size: 15, weight: isAchieved ? .semibold : .medium))
                    .foregroundStyle(
                        isAchieved ? .white :
                        isNext ? .primary :
                        Color(hex: "8E8E93")
                    )
            }

            // Subtext: date achieved OR days to go
            if isAchieved {
                Text(achievementDateString(for: milestone))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white)
            } else {
                Text("\(milestone - currentStreak) days to go")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isNext ? Color(hex: "8E8E93") : Color(hex: "AEAEB2"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isAchieved ? Color(hex: "00C7BE") : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isAchieved ? Color.clear :
                    isNext ? Color(hex: "00C7BE") :
                    Color(hex: "D1D1D6"),
                    lineWidth: 1.5
                )
        )
        .onTapGesture {
            handleMilestoneTap(milestone: milestone, isAchieved: isAchieved)
        }
        // VoiceOver accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(milestoneAccessibilityLabel(for: milestone, isAchieved: isAchieved))
    }

    // MARK: - Achievement Date Calculation

    private func achievementDateString(for milestone: Int) -> String {
        guard let startDate = streakStartDate else { return "" }
        let calendar = Calendar.current
        if let achievedDate = calendar.date(byAdding: .day, value: milestone - 1, to: startDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: achievedDate)
        }
        return ""
    }

    // MARK: - Accessibility

    private func milestoneAccessibilityLabel(for milestone: Int, isAchieved: Bool) -> String {
        let name = milestoneLabel(milestone)
        if isAchieved {
            return "\(name) achieved. \(milestone) days."
        } else {
            let daysToGo = milestone - currentStreak
            return "\(name). \(daysToGo) days to go."
        }
    }

    // MARK: - Tap Handling

    private func handleMilestoneTap(milestone: Int, isAchieved: Bool) {
        HapticService.shared.playSelection()

        if isAchieved {
            // Show date when milestone was achieved
            if let startDate = streakStartDate {
                let calendar = Calendar.current
                if let achievedDate = calendar.date(byAdding: .day, value: milestone - 1, to: startDate) {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    toastMessage = "\(milestoneLabel(milestone)) achieved \(formatter.string(from: achievedDate))!"
                } else {
                    toastMessage = "\(milestoneLabel(milestone)) achieved!"
                }
            } else {
                toastMessage = "\(milestoneLabel(milestone)) achieved!"
            }
        } else {
            // Show encouraging message for unachieved
            let daysToGo = milestone - currentStreak
            if daysToGo == 1 {
                toastMessage = "Just 1 more day to \(milestoneLabel(milestone))!"
            } else {
                toastMessage = "\(daysToGo) days until \(milestoneLabel(milestone))"
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingToast = true
        }

        // Auto-dismiss after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showingToast = false
            }
        }
    }

    // MARK: - Helpers

    private func milestoneLabel(_ days: Int) -> String {
        switch days {
        case 7: return "Week One"
        case 14: return "Two Weeks"
        case 30: return "Monthly"
        case 60: return "Dedicated"
        case 100: return "Triple Digits"
        case 365: return "Year Strong"
        default: return "\(days) days"
        }
    }
}

// MARK: - Previews

#Preview("Early Streak") {
    let calendar = Calendar.current
    let streakStart = calendar.date(byAdding: .day, value: -25, to: Date())

    return VStack(spacing: 20) {
        MilestonesRow(currentStreak: 3, streakStartDate: streakStart)
        MilestonesRow(currentStreak: 10, streakStartDate: streakStart)
        MilestonesRow(currentStreak: 25, streakStartDate: streakStart)
        MilestonesRow(currentStreak: 45, streakStartDate: streakStart)
        MilestonesRow(currentStreak: 100, streakStartDate: streakStart)
    }
    .padding()
}
