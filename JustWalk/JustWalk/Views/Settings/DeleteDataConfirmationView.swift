//
//  DeleteDataConfirmationView.swift
//  JustWalk
//
//  Confirmation flow for deleting all user data with strong safeguards
//

import SwiftUI

struct DeleteDataConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirmDelete: () -> Void

    @State private var confirmationText = ""
    @State private var isDeleting = false

    private var streakManager: StreakManager { StreakManager.shared }
    private var shieldManager: ShieldManager { ShieldManager.shared }

    private var walkCount: Int {
        PersistenceManager.shared.loadAllTrackedWalks().count
    }

    private var canDelete: Bool {
        confirmationText.uppercased() == "DELETE"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)
                        .padding(.top, 24)

                    // Warning text
                    VStack(spacing: 12) {
                        Text("Delete All Data?")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("This will permanently erase all your data from this device and iCloud. This action cannot be undone.")
                            .font(.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Data summary
                    VStack(spacing: 0) {
                        dataRow(label: "Walk History", value: "\(walkCount) walks", icon: "figure.walk")
                        Divider().padding(.leading, 50)
                        dataRow(label: "Current Streak", value: "\(streakManager.streakData.currentStreak) days", icon: "flame.fill")
                        Divider().padding(.leading, 50)
                        dataRow(label: "Longest Streak", value: "\(streakManager.streakData.longestStreak) days", icon: "trophy.fill")
                        Divider().padding(.leading, 50)
                        dataRow(label: "Shields", value: "\(shieldManager.shieldData.availableShields) remaining", icon: "shield.fill")
                        Divider().padding(.leading, 50)
                        dataRow(label: "Daily Logs", value: "All history", icon: "calendar")
                        Divider().padding(.leading, 50)
                        dataRow(label: "Settings", value: "All preferences", icon: "gearshape.fill")
                    }
                    .background(JW.Color.backgroundCard)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Confirmation input
                    VStack(spacing: 12) {
                        Text("Type DELETE to confirm")
                            .font(.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)

                        TextField("", text: $confirmationText)
                            .textFieldStyle(.plain)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .padding()
                            .background(JW.Color.backgroundCard)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(canDelete ? .red : Color.clear, lineWidth: 2)
                            )
                            .padding(.horizontal)
                    }

                    // Delete button
                    Button {
                        performDeletion()
                    } label: {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Delete Everything")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canDelete ? .red : .gray)
                        .cornerRadius(12)
                    }
                    .disabled(!canDelete || isDeleting)
                    .padding(.horizontal)

                    // Cancel hint
                    Text("This includes data stored in iCloud")
                        .font(.caption)
                        .foregroundStyle(JW.Color.textSecondary)
                        .padding(.bottom, 24)
                }
            }
            .scrollContentBackground(.hidden)
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Delete Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isDeleting)
    }

    private func dataRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.red.opacity(0.8))
                .frame(width: 24)

            Text(label)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func performDeletion() {
        isDeleting = true

        // Small delay to show progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Clear all local data
            PersistenceManager.shared.clearAllData()

            // Delete CloudKit data (zone and all records)
            CloudKitSyncManager.shared.deleteCloudData()

            // Clear KVS flag so reinstall doesn't think user is returning
            CloudKeyValueStore.clearAll()

            // Cancel all notifications
            NotificationManager.shared.cancelAllPendingNotifications()

            // Notify parent to handle the deletion
            onConfirmDelete()

            dismiss()
        }
    }
}

#Preview {
    DeleteDataConfirmationView(onConfirmDelete: {})
}
