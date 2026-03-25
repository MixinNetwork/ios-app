import SwiftUI
import RswiftResources

struct ManualText: ViewModifier {
    
    enum Style {
        case heading
        case subheading(UIColor)
        case body
        case caption1
        case caption2
    }
    
    private let weight: Font.Weight
    private let color: UIColor
    private let monospacedDigit: Bool
    
    @ScaledMetric
    private var size: CGFloat
    
    init(_ style: Style, monospacedDigit: Bool = false) {
        switch style {
        case .heading:
            self.weight = .medium
            self.color = R.color.text()!
            self._size = ScaledMetric(wrappedValue: 16, relativeTo: .title)
        case .subheading(let color):
            self.weight = .medium
            self.color = color
            self._size = ScaledMetric(wrappedValue: 14, relativeTo: .title)
        case .body:
            self.weight = .regular
            self.color = R.color.text_secondary()!
            self._size = ScaledMetric(wrappedValue: 14, relativeTo: .body)
        case .caption1:
            self.weight = .regular
            self.color = R.color.text()!
            self._size = ScaledMetric(wrappedValue: 14, relativeTo: .body)
        case .caption2:
            self.weight = .regular
            self.color = R.color.text_tertiary()!
            self._size = ScaledMetric(wrappedValue: 14, relativeTo: .body)
        }
        self.monospacedDigit = monospacedDigit
    }
    
    func body(content: Content) -> some View {
        if monospacedDigit {
            content.font(.system(size: size, weight: weight).monospacedDigit())
                .foregroundColor(Color(color))
                .lineSpacing(4)
        } else {
            content.font(.system(size: size, weight: weight))
                .foregroundColor(Color(color))
                .lineSpacing(4)
        }
    }
    
}
