import UIKit

class SnapCenterFlowLayout: UICollectionViewFlowLayout {
    
    var scale: CGFloat {
        didSet {
            guard oldValue != scale else {
                return
            }
            invalidateLayout()
        }
    }
    
    init(scale: CGFloat) {
        self.scale = scale
        super.init()
    }
    
    required init?(coder: NSCoder) {
        self.scale = 1
        super.init(coder: coder)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let superAttributes = super.layoutAttributesForElements(in: rect)
        guard
            scale != 0,
            let collectionView = collectionView,
            let layoutAttributes = superAttributes?.map({ $0.copy() }) as? [UICollectionViewLayoutAttributes]
        else {
            return superAttributes
        }
        let centerX = collectionView.contentOffset.x + collectionView.bounds.size.width / 2
        layoutAttributes.forEach { attributes in
            let distance = abs(attributes.center.x - centerX)
            let apartScale = distance / collectionView.bounds.size.width
            let scaleY = abs(cos(apartScale * scale))
            attributes.transform = CGAffineTransform(scaleX: 1.0, y: scaleY)
        }
        return layoutAttributes
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        scale != 0
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard
            let collectionView = collectionView,
            let attributes = layoutAttributesForElements(in: CGRect(origin: proposedContentOffset, size: collectionView.frame.size))
        else {
            return .zero
        }
        var targetPoint = proposedContentOffset
        var moveDistance = CGFloat.greatestFiniteMagnitude
        let centerX = proposedContentOffset.x + collectionView.bounds.width / 2
        attributes.forEach { (attr) in
            if abs(attr.center.x - centerX) < abs(moveDistance) {
                moveDistance = attr.center.x - centerX
            }
        }
        if targetPoint.x > 0 && targetPoint.x < collectionViewContentSize.width - collectionView.bounds.width {
            targetPoint.x += moveDistance
        }
        return targetPoint
    }
    
}
