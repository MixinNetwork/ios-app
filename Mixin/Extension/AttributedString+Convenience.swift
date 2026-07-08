import Foundation
import UIKit

extension AttributedString {
    
    init(
        string: String,
        scalingByFontSize fontSize: CGFloat,
        weight: UIFont.Weight = .regular
    ) {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: fontSize, weight: weight)
        )
        self.init(string, attributes: container)
    }
    
    init(string: String, font: UIFont) {
        var container = AttributeContainer()
        container.font = font
        self.init(string, attributes: container)
    }
    
}
