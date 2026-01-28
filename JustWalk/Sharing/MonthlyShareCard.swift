//
//  MonthlyShareCard.swift
//  JustWalk
//
//  Share card for monthly summary
//

import SwiftUI

struct MonthlyShareCard: View {
    let monthName: String
    let walksCompleted: Int
    let totalMinutes: Int
    let goalsMetCount: Int

    static let cardSize = CGSize(width: 1080, height: 1920)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0x0D/255, green: 0x0D/255, blue: 0x1A/255),
                    Color(red: 0x12/255, green: 0x12/255, blue: 0x20/255),
                    Color(red: 0x16/255, green: 0x14/255, blue: 0x28/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 60) {
                Spacer()

                // Month header
                Text(monthName)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Monthly Summary")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ], spacing: 20) {
                    ShareStatBlock(icon: "flame.fill", value: "\(walksCompleted)", label: "Walks")
                    ShareStatBlock(icon: "clock", value: formattedDuration, label: "Walk Time")
                    ShareStatBlock(icon: "checkmark.circle", value: "\(goalsMetCount)", label: "Goals Met")
                }
                .padding(.horizontal, 60)

                Spacer()
            }

            ShareCardBranding()
        }
    }

    private var formattedDuration: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
