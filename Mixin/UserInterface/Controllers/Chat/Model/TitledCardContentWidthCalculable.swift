import UIKit

protocol TitledCardContentWidthCalculable {
    
    func updateContentWidth(title: String?, titleFont: UIFont, subtitle: String?, subtitleFont: UIFont)
    
}

extension TitledCardContentWidthCalculable where Self: CardMessageViewModel {
    
    func updateContentWidth(title: String?, titleFont: UIFont, subtitle: String?, subtitleFont: UIFont) {
        let titleWidth = ((title ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: titleFont])
            .width
        let subtitleWidth = ((subtitle ?? "") as NSString)
            .size(withAttributes: [NSAttributedString.Key.font: subtitleFont])
            .width
        contentWidth = Self.leftViewSideLength
            + Self.spacing
            + ceil(max(titleWidth, subtitleWidth))
    }
    
}
