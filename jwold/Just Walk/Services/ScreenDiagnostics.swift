//
//  ScreenDiagnostics.swift
//  Just Walk
//
//  Diagnostic ViewModifier to debug iPhone 17 Pro Max scaling issues.
//  Drop this on your root view to see screen resolution data in the console.
//  NOTE: This file is only compiled in DEBUG builds.
//

import SwiftUI

#if DEBUG

/// Diagnostic modifier that prints screen bounds to console on appear
struct ScreenDiagnosticsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ScreenDiagnosticsView())
    }
}

/// Hidden view that captures window context for screen diagnostics
private struct ScreenDiagnosticsView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        
        // Defer to next run loop to allow view to be added to window hierarchy
        DispatchQueue.main.async {
            printScreenDiagnostics(from: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    private func printScreenDiagnostics(from view: UIView) {
        // Get screen from window scene (iOS 26+ compliant, no UIScreen.main)
        guard let windowScene = view.window?.windowScene else {
            print("⚠️ ScreenDiagnostics: Unable to access windowScene - view not in window hierarchy")
            return
        }
        
        let screen = windowScene.screen
        
        print("═══════════════════════════════════════════════════════════")
        print("  SCREEN DIAGNOSTICS - iPhone Display Mode Check")
        print("═══════════════════════════════════════════════════════════")
        print("")
        print("  UIScreen.bounds:        \(screen.bounds)")
        print("  UIScreen.nativeBounds:  \(screen.nativeBounds)")
        print("  UIScreen.scale:         \(screen.scale)x")
        print("  UIScreen.nativeScale:   \(screen.nativeScale)x")
        print("")
        
        // Expected resolutions for iPhone Pro Max devices
        // iPhone 14/15/16 Pro Max: 430 x 932 points @ 3x = 1290 x 2796 native
        // iPhone 17 Pro Max: Expected similar or slightly larger
        let expectedProMaxWidth: CGFloat = 430    // Points (Pro Max width)
        let expectedProMaxHeight: CGFloat = 932   // Points (Pro Max height)
        let standardWidth: CGFloat = 393          // iPhone Pro (non-Max)
        let standardHeight: CGFloat = 852         // iPhone Pro (non-Max)
        
        let actualWidth = screen.bounds.width
        let actualHeight = screen.bounds.height
        
        // Calculate scaling ratio for Pro Max detection
        let widthRatio = actualWidth / expectedProMaxWidth
        let heightRatio = actualHeight / expectedProMaxHeight
        
        // Device is in zoomed mode if dimensions are smaller than expected Pro Max
        // AND match or are close to standard (non-Max) dimensions
        let isZoomedMode = actualWidth < expectedProMaxWidth &&
                           actualWidth <= standardWidth &&
                           actualHeight <= standardHeight
        
        print("  SCALING ANALYSIS:")
        print("  - Expected Pro Max: \(expectedProMaxWidth) x \(expectedProMaxHeight) points")
        print("  - Actual:           \(actualWidth) x \(actualHeight) points")
        print("  - Width Ratio:      \(String(format: "%.2f", widthRatio)) (\(widthRatio >= 1.0 ? "OK" : "SCALED DOWN"))")
        print("  - Height Ratio:     \(String(format: "%.2f", heightRatio)) (\(heightRatio >= 1.0 ? "OK" : "SCALED DOWN"))")
        print("")
        
        if isZoomedMode {
            print("  ⚠️  WARNING: App appears to be in ZOOMED/COMPATIBILITY mode!")
            print("      Expected Pro Max dimensions: ≥\(expectedProMaxWidth) x \(expectedProMaxHeight) points")
            print("      Actual dimensions: \(actualWidth) x \(actualHeight) points")
            print("")
            print("  POSSIBLE CAUSES:")
            print("  1. Missing launch screen configuration")
            print("  2. App built with old SDK that doesn't recognize device")
            print("  3. Simulator set to 'Zoomed' display mode")
            print("  4. Physical device set to 'Zoomed' in Settings > Display & Brightness")
        } else {
            print("  ✅ SUCCESS: App is running at native resolution")
            print("     Screen dimensions indicate full Pro Max support")
        }
        
        print("")
        print("  DEVICE INFO:")
        print("  - Model: \(UIDevice.current.model)")
        print("  - System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        print("")
        print("═══════════════════════════════════════════════════════════")
    }
}

extension View {
    /// Add to root view to diagnose screen scaling issues (DEBUG only)
    func screenDiagnostics() -> some View {
        modifier(ScreenDiagnosticsModifier())
    }
}

#else

// No-op extension for Release builds
extension View {
    /// No-op in release builds
    func screenDiagnostics() -> some View {
        self
    }
}

#endif

