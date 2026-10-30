import UIKit

final class ExploreContactSectionBackgroundView: UICollectionReusableView {
    
    enum Corners: String, CaseIterable {
        case all = "ExploreContactSectionBackgroundAll"
        case top = "ExploreContactSectionBackgroundTop"
        case bottom = "ExploreContactSectionBackgroundBottom"
        case none = "ExploreContactSectionBackgroundNone"
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
        case Corners.all.rawValue:
            layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner,
            ]
        case Corners.top.rawValue:
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        case Corners.bottom.rawValue:
            layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        default:
            layer.maskedCorners = []
        }
    }
    
    private func updateStyle() {
        backgroundColor = R.color.background()
        layer.cornerRadius = 13
        layer.masksToBounds = true
    }
    
}
