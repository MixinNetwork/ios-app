import UIKit

class StickersStoreBannerFlowLayout: UICollectionViewFlowLayout {
    
    override func prepare() {
        super.prepare()
        collectionView?.decelerationRate = .fast
        itemSize = ScreenWidth.current <= .short ? CGSize(width: 273, height: 170) : CGSize(width: 320, height: 200)
        let horizontalInset = floor((UIScreen.main.bounds.width - itemSize.width) / 2)
        sectionInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
        minimumLineSpacing = 6
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard
            let collectionView = collectionView,
            let layoutAttributes = copy(super.layoutAttributesForElements(in: rect))
        else {
            return nil
        }
        let centerX = collectionView.contentOffset.x + collectionView.bounds.size.width / 2
        layoutAttributes.forEach { attributes in
            let distance = abs(attributes.center.x - centerX)
            let apartScale = distance / collectionView.bounds.size.width
            let scale = abs(cos(apartScale * .pi / 4))
            attributes.transform = CGAffineTransform(scaleX: 1.0, y: scale)
        }
        return layoutAttributes
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard
            let collectionView = collectionView,
            let attributes = layoutAttributesForElements(in: CGRect(x: proposedContentOffset.x,
                                                                    y: proposedContentOffset.y,
                                                                    width: collectionView.bounds.size.width,
                                                                    height: collectionView.bounds.size.height))
        else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
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
    
    private func copy(_ layoutAttributesArray: [UICollectionViewLayoutAttributes]?) -> [UICollectionViewLayoutAttributes]? {
        return layoutAttributesArray?.map{ $0.copy() } as? [UICollectionViewLayoutAttributes]
    }
    
}
