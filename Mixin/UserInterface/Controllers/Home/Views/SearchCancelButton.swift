import UIKit

final class SearchCancelButton: UIButton {
    
    convenience init() {
        var config: UIButton.Configuration = .plain()
        config.attributedTitle = AttributedString(
            string: R.string.localizable.cancel(),
            textStyle: .callout
        )
        config.baseForegroundColor = .theme
        if #unavailable(iOS 26.0) {
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 0)
        }
        self.init(configuration: config)
        titleLabel?.adjustsFontForContentSizeCategory = true
        sizeToFit()
        frame.size.height = 44
    }
    
}
