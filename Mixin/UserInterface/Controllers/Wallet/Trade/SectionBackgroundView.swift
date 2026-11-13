import UIKit

final class SectionBackgroundView: UICollectionReusableView {
    
    enum CornerRadius: String {
        case none = "SectionBackgroundNoCorner"
        case small = "SectionBackgroundSmallCorner"
        case smallTop = "SectionBackgroundSmallTopCorner"
        case smallBottom = "SectionBackgroundSmallBottomCorner"
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
            layer.maskedCorners = [
                .layerMinXMinYCorner,
                .layerMaxXMinYCorner,
                .layerMinXMaxYCorner,
                .layerMaxXMaxYCorner,
            ]
        case CornerRadius.smallTop.rawValue:
            layer.cornerRadius = 8
            layer.maskedCorners = [
                .layerMinXMinYCorner,
                .layerMaxXMinYCorner
            ]
        case CornerRadius.smallBottom.rawValue:
            layer.cornerRadius = 8
            layer.maskedCorners = [
                .layerMinXMaxYCorner,
                .layerMaxXMaxYCorner
            ]
        case CornerRadius.large.rawValue:
            layer.cornerRadius = 13
            layer.maskedCorners = [
                .layerMinXMinYCorner,
                .layerMaxXMinYCorner,
                .layerMinXMaxYCorner,
                .layerMaxXMaxYCorner,
            ]
        default:
            layer.cornerRadius = 0
            layer.maskedCorners = [
                .layerMinXMinYCorner,
                .layerMaxXMinYCorner,
                .layerMinXMaxYCorner,
                .layerMaxXMaxYCorner,
            ]
        }
    }
    
    private func updateStyle() {
        backgroundColor = R.color.background()
        layer.masksToBounds = true
    }
    
}
