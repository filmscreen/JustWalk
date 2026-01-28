import SwiftUI

struct AvailableGlassModifier: ViewModifier {
    let tintColor: Color?

    init(tintColor: Color? = nil) {
        self.tintColor = tintColor
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let c = tintColor {
                content.glassEffect(.regular.tint(c).interactive())
            } else {
                content.glassEffect()
            }
        } else {
            content
                .background(.regularMaterial)
                .cornerRadius(8)
        }
    }
}

extension View {
    func jwGlassEffect(tintColor: Color? = nil) -> some View {
        modifier(AvailableGlassModifier(tintColor: tintColor))
    }
}
