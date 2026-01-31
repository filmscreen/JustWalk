import SwiftUI

struct LogoConceptView: View {
    var body: some View {
        ZStack {
            // Background: Indigo/Navy
            JW.Color.backgroundPrimary
                .ignoresSafeArea()
            
            // Icon: Vibrant Teal Walking Man
            Image(systemName: "figure.walk")
                .resizable()
                .scaledToFit()
                .foregroundStyle(JW.Color.accent)
                .padding(20) // Adjust padding to insure it's big but not touching edges
        }
    }
}

#Preview {
    LogoConceptView()
}
