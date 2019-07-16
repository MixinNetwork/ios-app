import UIKit

class LiveStreamBadgeView: InsetLabel {
    
    override var backgroundColor: UIColor? {
        get {
            return super.backgroundColor
        }
        set {
            
        }
    }
    
    convenience init() {
        let frame = CGRect(x: 0, y: 0, width: 35, height: 17)
        self.init(frame: frame)
        contentInset = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        super.backgroundColor = UIColor(displayP3RgbValue: 0xF14C7C)
        textColor = .white
        text = R.string.localizable.chat_badge_live()
        font = .systemFont(ofSize: 12, weight: .bold)
        sizeToFit()
        layer.cornerRadius = bounds.size.height / 2
        clipsToBounds = true
    }
    
}
