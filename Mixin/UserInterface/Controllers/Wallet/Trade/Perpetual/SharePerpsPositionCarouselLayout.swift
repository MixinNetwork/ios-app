import UIKit

final class SharePerpsPositionCarouselLayout: UICollectionViewFlowLayout {
    
    private let scale: CGFloat = 0.874
    private let margin: CGFloat = 28
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let superAttributes = super.layoutAttributesForElements(in: rect)
        guard let collectionView = collectionView, let superAttributes else {
            return superAttributes
        }
        let attributes = superAttributes.compactMap {
            $0.copy() as? UICollectionViewLayoutAttributes
        }
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let visibleCenterX = visibleRect.midX
        let itemWidth = itemSize.width
        let distance = itemWidth + minimumLineSpacing
        let focusWidth = max(0, collectionView.bounds.width - margin * 2)
        let normWidth = focusWidth * scale
        let focusScale = focusWidth / itemWidth
        let normScale = normWidth / itemWidth
        let delta1 = (focusWidth + normWidth) / 2 - itemWidth
        let deltaNorm = normWidth - itemWidth
        
        for attribute in attributes {
            let x = attribute.center.x - visibleCenterX
            let sign: CGFloat = x < 0 ? -1 : 1
            let absX = abs(x)
            let t = absX / distance
            
            var scale: CGFloat = 1
            var shift: CGFloat = 0
            if t <= 1 {
                scale = normScale + (focusScale - normScale) * (1 - t)
                shift = t * delta1
            } else {
                scale = normScale
                shift = delta1 + (t - 1) * deltaNorm
            }
            attribute.center.x += sign * shift
            attribute.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            // Ensure the center-most item is always drawn on top
            attribute.zIndex = Int(scale * 1000)
        }
        
        return attributes
    }
    
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let collectionView = collectionView else {
            return proposedContentOffset
        }
        let proposedRect = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height
        )
        let proposedCenterX = proposedRect.midX
        guard let attributes = super.layoutAttributesForElements(in: proposedRect) else {
            return proposedContentOffset
        }
        var closestAttribute: UICollectionViewLayoutAttributes?
        var minDistance = CGFloat.greatestFiniteMagnitude
        for attribute in attributes {
            let distance = abs(attribute.center.x - proposedCenterX)
            if distance < minDistance {
                minDistance = distance
                closestAttribute = attribute
            }
        }
        guard let closest = closestAttribute else {
            return proposedContentOffset
        }
        return CGPoint(
            x: closest.center.x - collectionView.bounds.width / 2,
            y: proposedContentOffset.y
        )
    }
    
}
