import UIKit

final class TradeSectionBackgroundView: UICollectionReusableView {
    
    enum CornerRadius: String {
        case small = "TradeSectionBackground"
        case large = "TradeSectionBackgroundLarge"
    }
    
    static let elementKind = CornerRadius.small.rawValue
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        updateStyle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        updateStyle()
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        switch layoutAttributes.representedElementKind {
        case CornerRadius.large.rawValue:
            layer.cornerRadius = 13
        default:
            layer.cornerRadius = 8
        }
    }
    
    private func updateStyle() {
        backgroundColor = R.color.background()
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
}
