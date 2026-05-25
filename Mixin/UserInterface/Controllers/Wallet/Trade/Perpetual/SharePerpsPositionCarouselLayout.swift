import UIKit

final class SharePerpsPositionCarouselLayout: UICollectionViewFlowLayout {
    
    private let scale: CGFloat = 0.874
    
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        let horizontalInset = (collectionView.bounds.width - itemSize.width) / 2
        sectionInset = UIEdgeInsets(
            top: 0,
            left: horizontalInset,
            bottom: 0,
            right: horizontalInset
        )
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let superAttributes = super.layoutAttributesForElements(in: rect)
        guard
            let collectionView = collectionView,
            let attributes = superAttributes?.map({ $0.copy() }) as? [UICollectionViewLayoutAttributes]
        else {
            return superAttributes
        }
        let visibleCenterX = collectionView.contentOffset.x + collectionView.bounds.width / 2
        for attribute in attributes {
            let distance = abs(attribute.center.x - visibleCenterX)
            let maxDistance = itemSize.width + minimumLineSpacing
            let normalizedDistance = min(distance / maxDistance, 1)
            let scale = 1 - ((1 - scale) * normalizedDistance)
            attribute.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
        return attributes
    }
    
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
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
