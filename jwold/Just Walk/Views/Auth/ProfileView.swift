//
//  ProfileView.swift
//  Just Walk
//
//  User profile section showing auth state and sign out option.
//

import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if authViewModel.isAuthenticated {
            // Authenticated State
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(CircleTheme.accentGradient)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Managing Partner")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("Signed in with Apple")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Pro Badge (if applicable)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                
                Divider()
                
                // Sign Out Link
                Button(action: {
                    Task {
                        await authViewModel.signOut()
                    }
                }) {
                    Text("Sign Out")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(CircleTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            // Unauthenticated State
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundStyle(CircleTheme.accentCyan)
                    
                    Text("Welcome Back")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Sign in to sync your Circles across devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Sign in with Apple Button
                Button(action: {
                    Task {
                        await authViewModel.signInWithApple()
                    }
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Sign in with Apple")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .clipShape(Capsule())
                }
                .disabled(authViewModel.isLoading)
                .opacity(authViewModel.isLoading ? 0.6 : 1)
                
                if authViewModel.isLoading {
                    ProgressView()
                }
                
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(CircleTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview("Authenticated") {
    let vm = AuthViewModel()
    vm.isAuthenticated = true
    return ProfileView(authViewModel: vm)
        .padding()
        .background(Color.black)
}

#Preview("Unauthenticated") {
    ProfileView(authViewModel: AuthViewModel())
        .padding()
        .background(Color.black)
}
