import SwiftUI

struct ScaledFont: ViewModifier {
    
    private let weight: Font.Weight
    
    @ScaledMetric private var size: CGFloat
    
    init(size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
    
}
