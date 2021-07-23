import UIKit

class StickerStoreBannerFlowLayout: UICollectionViewFlowLayout {
    
    override func prepare() {
        super.prepare()
        let inset = (UIScreen.main.bounds.width - itemSize.width)/2
        sectionInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        minimumLineSpacing = 6
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let collectionView = collectionView,
              let layoutAttributes = super.layoutAttributesForElements(in: rect) else {
            return super.layoutAttributesForElements(in: rect)
        }
        let centerX = collectionView.contentOffset.x + collectionView.bounds.size.width/2
        layoutAttributes.forEach { attributes in
            let distance = abs(attributes.center.x - centerX)
            let apartScale = distance/collectionView.bounds.size.width
            let scale = abs(cos(apartScale * CGFloat.pi/4))
            attributes.transform = CGAffineTransform(scaleX: 1.0, y: scale)
        }
        return layoutAttributes
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView,
              let attributes = layoutAttributesForElements(in: CGRect(x: proposedContentOffset.x, y: proposedContentOffset.y, width: collectionView.bounds.size.width, height: collectionView.bounds.size.height)) else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        var targetPoint = proposedContentOffset
        let centerX = proposedContentOffset.x + collectionView.bounds.width / 2
        var moveDistance: CGFloat = CGFloat(MAXFLOAT)
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
