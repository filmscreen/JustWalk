//
//  SupabaseManager.swift
//  Just Walk
//
//  Manages Supabase client connection for backend features.
//  Currently used for: Gifted shields (user support system)
//

import Foundation
import Supabase

/// Configuration for Supabase connection
/// ⚠️ IMPORTANT: Replace these with your actual Supabase project credentials
enum SupabaseConfig {
    // TODO: Replace with your Supabase project URL (from Project Settings > API)
    static let projectURL = "https://your-project-id.supabase.co"

    // TODO: Replace with your Supabase anon/public key (from Project Settings > API)
    static let anonKey = "your-anon-key-here"
}

/// Singleton manager for Supabase client
@MainActor
final class SupabaseManager {

    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Client

    /// The Supabase client instance
    let client: SupabaseClient

    /// Whether Supabase is properly configured (not using placeholder values)
    var isConfigured: Bool {
        !SupabaseConfig.projectURL.contains("your-project-id") &&
        !SupabaseConfig.anonKey.contains("your-anon-key")
    }

    // MARK: - Init

    private init() {
        guard let url = URL(string: SupabaseConfig.projectURL) else {
            fatalError("Invalid Supabase URL: \(SupabaseConfig.projectURL)")
        }

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.anonKey
        )

        if !isConfigured {
            print("⚠️ SupabaseManager: Using placeholder credentials. Update SupabaseConfig with your project details.")
        } else {
            print("✅ SupabaseManager: Configured with project URL")
        }
    }
}
