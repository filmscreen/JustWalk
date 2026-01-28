//
//  SavedRoutesSheet.swift
//  Just Walk
//
//  Modal sheet for viewing all saved routes.
//  Shows route list with swipe-to-delete, empty state, and pro upsell.
//

import SwiftUI

struct SavedRoutesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var savedRouteManager = SavedRouteManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var onSelectRoute: (SavedRoute) -> Void = { _ in }
    var onGenerateFirst: () -> Void = {}
    var onShowPaywall: () -> Void = {}

    @State private var selectedRouteForDetail: SavedRoute?

    var body: some View {
        NavigationStack {
            Group {
                if savedRouteManager.savedRoutes.isEmpty {
                    emptyState
                } else {
                    routesList
                }
            }
            .navigationTitle("Saved Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: $selectedRouteForDetail) { route in
                SavedRouteDetailView(route: route) { generatedRoute in
                    selectedRouteForDetail = nil
                    dismiss()
                    onSelectRoute(route)
                }
            }
        }
    }

    // MARK: - Routes List

    private var routesList: some View {
        List {
            ForEach(savedRouteManager.savedRoutes) { route in
                Button {
                    selectedRouteForDetail = route
                } label: {
                    SavedRouteCard(route: route)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteRoutes)

            // Pro upsell at bottom if at free limit
            if savedRouteManager.isAtFreeLimit && !subscriptionManager.isPro {
                proUpsellBanner
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No saved routes yet")
                .font(.headline)

            Text("Complete a Magic Route walk and save it to walk again later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Generate Your First") {
                dismiss()
                onGenerateFirst()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "00C7BE"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Pro Upsell Banner

    private var proUpsellBanner: some View {
        Button {
            onShowPaywall()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Unlimited Routes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Upgrade to Pro")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            let route = savedRouteManager.savedRoutes[index]
            savedRouteManager.deleteRoute(route)
        }
    }
}

// MARK: - Preview

#Preview("With Routes") {
    SavedRoutesSheet(
        onSelectRoute: { route in print("Selected: \(route.name)") },
        onGenerateFirst: { print("Generate first") },
        onShowPaywall: { print("Show paywall") }
    )
}

#Preview("Empty State") {
    SavedRoutesSheet()
}
