//
//  LoginView.swift
//  Just Walk
//
//  Minimalist login screen for authentication.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Ambient Glow
            Circle()
                .fill(CircleTheme.midnightBlue.opacity(0.2))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -100)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Branding
                VStack(spacing: 16) {
                    // App Icon
                    ZStack {
                        Circle()
                            .fill(CircleTheme.accentGradient)
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "figure.walk")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: CircleTheme.accentCyan.opacity(0.5), radius: 20)
                    
                    VStack(spacing: 8) {
                        Text("Just Walk")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Your premium walking companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Sign In Section
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Welcome Back")
                            .font(CircleTheme.partnerHeader)
                            .foregroundStyle(.white)
                        
                        Text("Sign in to sync your Circles and data across devices")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Sign in with Apple Button
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { _ in
                        // Handled by AuthViewModel
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 56)
                    .clipShape(Capsule())
                    .overlay(
                        Group {
                            if authViewModel.isLoading {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(ProgressView().tint(.white))
                            }
                        }
                    )
                    .disabled(authViewModel.isLoading)
                    .onTapGesture {
                        Task {
                            await authViewModel.signInWithApple()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Error Message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                
                Spacer()
                
                // Skip Option (for users who want to explore without signing in)
                Button(action: {
                    // Allow browsing without auth - handled by parent view
                }) {
                    Text("Continue without signing in")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    LoginView(authViewModel: AuthViewModel())
}
