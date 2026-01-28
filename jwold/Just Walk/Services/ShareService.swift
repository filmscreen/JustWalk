//
//  ShareService.swift
//  Just Walk
//
//  Service for rendering share cards to images and presenting share sheets.
//

import SwiftUI
import UIKit

@MainActor
final class ShareService {
    static let shared = ShareService()

    // MARK: - Share Card Sizes

    /// Story format (Instagram Stories, TikTok)
    static let storySize = CGSize(width: 1080, height: 1920)

    /// Square format (Instagram Feed, Facebook)
    static let squareSize = CGSize(width: 1080, height: 1080)

    /// Preview size (1/3 scale for UI display)
    static let previewScale: CGFloat = 3.0

    // MARK: - Render SwiftUI View to Image

    /// Renders any SwiftUI view to a UIImage at the specified size
    func renderToImage<V: View>(_ view: V, size: CGSize) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    /// Renders a share card to the appropriate sized image
    func renderShareCard(_ cardType: ShareCardType) -> UIImage? {
        let size: CGSize
        switch cardType {
        case .walkerCard:
            size = Self.squareSize  // 1080x1080
        default:
            size = Self.storySize   // 1080x1920
        }
        let cardView = ShareCardRenderer(cardType: cardType)
        return renderToImage(cardView, size: size)
    }

    // MARK: - Present Share Sheet

    /// Presents the native share sheet with an image and optional caption
    func presentShareSheet(image: UIImage, caption: String, from viewController: UIViewController? = nil) {
        let activityItems: [Any] = [image, caption]

        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // Exclude some activities that don't make sense for sharing images
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]

        // Get the presenting view controller
        let presenter = viewController ?? Self.topViewController()

        // For iPad, set the popover source
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        presenter?.present(activityVC, animated: true)
    }

    /// Convenience method to share a card type directly
    func shareCard(_ cardType: ShareCardType, from viewController: UIViewController? = nil) {
        guard let image = renderShareCard(cardType) else {
            print("Failed to render share card")
            return
        }

        let caption = cardType.suggestedCaption
        presentShareSheet(image: image, caption: caption, from: viewController)
    }

    // MARK: - Helper to get top view controller

    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              var topController = window.rootViewController else {
            return nil
        }

        while let presented = topController.presentedViewController {
            topController = presented
        }

        return topController
    }
}

// MARK: - Share Card Renderer (Routes to correct template)

struct ShareCardRenderer: View {
    let cardType: ShareCardType

    var body: some View {
        switch cardType {
        case .dailyGoal(let data):
            DailyGoalShareCard(data: data)
        case .streakMilestone(let data):
            StreakMilestoneShareCard(data: data)
        case .weeklySnapshot(let data):
            WeeklySnapshotShareCard(data: data)
        case .personalRecord(let data):
            PersonalRecordShareCard(data: data)
        case .workout(let data):
            WorkoutShareCard(data: data)
        case .walkerCard(let data):
            WalkerCardView(data: data)
        }
    }
}

// MARK: - Placeholder Card Views (to be replaced with full implementations)

struct WeeklySnapshotShareCard: View {
    let data: WeeklySnapshotShareData

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.6, blue: 0.6),
                    Color(red: 0.0, green: 0.3, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 40) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("WEEK IN REVIEW")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(2)
                    Text(data.formattedDateRange)
                        .font(.system(size: 18))
                        .opacity(0.8)
                }

                // Hero stat
                VStack(spacing: 8) {
                    Text(data.formattedTotalSteps)
                        .font(.system(size: 72, weight: .bold))
                    Text("total steps")
                        .font(.system(size: 20))
                        .opacity(0.8)
                }

                // Supporting stats
                VStack(spacing: 12) {
                    Text("\(data.formattedDailyAverage) avg  •  Best: \(data.formattedBestDay ?? "N/A")")
                        .font(.system(size: 18))
                    Text("\(data.formattedMiles) walked this week")
                        .font(.system(size: 18))
                        .opacity(0.8)
                }

                Spacer()

                // Branding
                ShareCardBranding(style: .light)
                    .padding(.bottom, 60)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 1080, height: 1920)
    }
}

struct PersonalRecordShareCard: View {
    let data: PersonalRecordShareData

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.6, blue: 0.1),
                    Color(red: 0.8, green: 0.4, blue: 0.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 40) {
                Spacer()

                // Header
                Text("NEW RECORD")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(3)

                // Record type
                VStack(spacing: 16) {
                    Image(systemName: data.recordType.icon)
                        .font(.system(size: 48))
                    Text(data.recordType.displayName.uppercased())
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(1)
                }

                // Value
                Text(data.newValue)
                    .font(.system(size: 72, weight: .bold))

                // Previous
                if let previous = data.previousValue {
                    Text("Previous best: \(previous)")
                        .font(.system(size: 18))
                        .opacity(0.8)
                }

                Spacer()

                // Date
                Text(data.formattedDate)
                    .font(.system(size: 18))
                    .opacity(0.8)
                    .padding(.bottom, 24)

                // Branding
                ShareCardBranding(style: .light)
                    .padding(.bottom, 60)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 1080, height: 1920)
    }
}
