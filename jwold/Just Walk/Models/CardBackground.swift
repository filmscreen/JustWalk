//
//  CardBackground.swift
//  Just Walk
//
//  Background options for shareable Walker Card.
//  Includes free and Pro-gated options.
//

import SwiftUI

enum CardBackground: String, CaseIterable, Identifiable {
    // Free (3 options)
    case solidDark       // Rank color at 20% brightness
    case solidBlack      // Pure black
    case solidNavy       // Deep navy (#1C2541)

    // Pro (5 options)
    case gradientRank    // Rank color gradient
    case natureForest    // Forest path image
    case natureBeach     // Beach sunrise image
    case natureMountain  // Mountain trail image
    case customColor     // User color picker

    var id: String { rawValue }

    var isPro: Bool {
        switch self {
        case .solidDark, .solidBlack, .solidNavy:
            return false
        case .gradientRank, .natureForest, .natureBeach, .natureMountain, .customColor:
            return true
        }
    }

    var displayName: String {
        switch self {
        case .solidDark: return "Dark"
        case .solidBlack: return "Black"
        case .solidNavy: return "Navy"
        case .gradientRank: return "Gradient"
        case .natureForest: return "Forest"
        case .natureBeach: return "Beach"
        case .natureMountain: return "Mountain"
        case .customColor: return "Custom"
        }
    }

    /// Preview color for the selector
    var previewColor: Color {
        switch self {
        case .solidDark: return Color.gray.opacity(0.3)
        case .solidBlack: return Color.black
        case .solidNavy: return Color(hex: "1C2541")
        case .gradientRank: return Color.purple  // Placeholder, will use rank color
        case .natureForest: return Color.green.opacity(0.7)
        case .natureBeach: return Color.orange.opacity(0.7)
        case .natureMountain: return Color.blue.opacity(0.7)
        case .customColor: return Color.clear  // Rainbow indicator
        }
    }

    /// Returns true if this background uses an image asset
    var isImageBackground: Bool {
        switch self {
        case .natureForest, .natureBeach, .natureMountain:
            return true
        default:
            return false
        }
    }

    /// Image asset name for nature backgrounds
    var imageAssetName: String? {
        switch self {
        case .natureForest: return "bg_forest"
        case .natureBeach: return "bg_beach"
        case .natureMountain: return "bg_mountain"
        default: return nil
        }
    }

    // MARK: - Background View Builder

    /// Creates the background view for the card
    @ViewBuilder
    func backgroundView(rankColor: Color, customColor: Color?) -> some View {
        switch self {
        case .solidDark:
            // Rank color at 20% brightness
            rankColor.opacity(0.2)
                .background(Color.black)

        case .solidBlack:
            Color.black

        case .solidNavy:
            Color(hex: "1C2541")

        case .gradientRank:
            // Gradient from rank color to darker shade
            LinearGradient(
                colors: [
                    rankColor,
                    rankColor.opacity(0.6),
                    Color.black.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .natureForest, .natureBeach, .natureMountain:
            // Image background with fallback
            if let assetName = imageAssetName {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(Color.black.opacity(0.4))  // Darken for text readability
            } else {
                Color.black
            }

        case .customColor:
            // User-selected custom color with gradient
            if let color = customColor {
                LinearGradient(
                    colors: [
                        color,
                        color.opacity(0.6),
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.black
            }
        }
    }
}

// MARK: - Free Backgrounds Array

extension CardBackground {
    static var freeBackgrounds: [CardBackground] {
        [.solidDark, .solidBlack, .solidNavy]
    }

    static var proBackgrounds: [CardBackground] {
        [.gradientRank, .natureForest, .natureBeach, .natureMountain, .customColor]
    }
}
