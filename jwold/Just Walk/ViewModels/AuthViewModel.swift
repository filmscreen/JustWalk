//
//  AuthViewModel.swift
//  Just Walk
//
//  Stub AuthViewModel for compilation. Auth features removed with Circles.
//

import SwiftUI
import Combine

/// Minimal stub - Auth features were removed with Circles/Supabase
@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var displayName: String = "Walker"
    @Published var email: String?
    
    // MARK: - Singleton (for convenience)
    
    static let shared = AuthViewModel()
    
    // MARK: - Init
    
    init() {}
    
    // MARK: - Stub Methods
    
    func signInWithApple() async {
        // Auth removed with Circles feature
        print("⚠️ Auth disabled - Circles feature removed")
    }
    
    func signOut() async {
        // Auth removed with Circles feature
        print("⚠️ Auth disabled - Circles feature removed")
    }
    
    func deleteAccount() async {
        // Auth removed with Circles feature
        print("⚠️ Auth disabled - Circles feature removed")
    }
}
