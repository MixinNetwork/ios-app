import UIKit

class MessageTagLabel: InsetLabel {
    
    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 8, height: 2))
        layer.backgroundColor = UIColor.black.withAlphaComponent(0.4).cgColor
        textColor = .white
        font = .preferredFont(forTextStyle: .caption1)
        adjustsFontForContentSizeCategory = true
        numberOfLines = 1
        layer.cornerRadius = 4
        clipsToBounds = true
        contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
    }
    
}
