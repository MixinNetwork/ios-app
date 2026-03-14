import UIKit

final class TradeSectionBackgroundView: UICollectionReusableView {
    
    static let elementKind = "TradeSectionBackground"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        updateStyle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateStyle()
    }
    
    private func updateStyle() {
        backgroundColor = R.color.background()
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
}
