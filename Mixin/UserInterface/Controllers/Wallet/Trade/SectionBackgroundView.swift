import UIKit

final class SectionBackgroundView: UICollectionReusableView {
    
    enum CornerRadius: String {
        case none = "SectionBackgroundNoCorner"
        case small = "SectionBackgroundSmallCorner"
        case large = "SectionBackgroundLargeCorner"
    }
    
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
        case CornerRadius.small.rawValue:
            layer.cornerRadius = 8
        case CornerRadius.large.rawValue:
            layer.cornerRadius = 13
        default:
            layer.cornerRadius = 0
        }
    }
    
    private func updateStyle() {
        backgroundColor = R.color.background()
        layer.masksToBounds = true
    }
    
}
