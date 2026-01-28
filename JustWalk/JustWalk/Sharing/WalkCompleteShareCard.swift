//
//  WalkCompleteShareCard.swift
//  JustWalk
//
//  Share card for walk completion
//

import SwiftUI

struct WalkCompleteShareCard: View {
    let durationMinutes: Int
    let steps: Int
    let distanceMeters: Double
    let routeMapImage: UIImage?
    let useMetric: Bool

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

                // Header
                Text("Walk Complete!")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Stats Row
                HStack(spacing: 24) {
                    ShareStatColumn(value: "\(durationMinutes)m", label: "Duration")
                    ShareStatColumn(value: steps.formatted(), label: "Steps")
                    ShareStatColumn(value: formattedDistance, label: "Distance")
                }
                .padding(.horizontal, 60)

                // Route Map
                if let mapImage = routeMapImage {
                    Image(uiImage: mapImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 60)
                }

                Spacer()
            }

            ShareCardBranding()
        }
    }

    private var formattedDistance: String {
        if useMetric {
            if distanceMeters < 1000 {
                return "\(Int(distanceMeters))m"
            }
            return String(format: "%.1f km", distanceMeters / 1000)
        } else {
            return String(format: "%.2f mi", distanceMeters / 1609.344)
        }
    }
}
