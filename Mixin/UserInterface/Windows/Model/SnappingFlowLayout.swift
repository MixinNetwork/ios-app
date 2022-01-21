import UIKit

class SnappingFlowLayout: UICollectionViewFlowLayout {
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else {
            return .zero
        }
        let targetRect = CGRect(origin: proposedContentOffset, size: collectionView.frame.size)
        guard let layoutAttributesArray = layoutAttributesForElements(in: targetRect) else {
            return .zero
        }
        let centerX = proposedContentOffset.x + collectionView.frame.size.width / 2
        var adjustOffsetX = CGFloat.greatestFiniteMagnitude
        for layoutAttributes in layoutAttributesArray {
            if abs(layoutAttributes.center.x - centerX) < abs(adjustOffsetX) {
                adjustOffsetX = layoutAttributes.center.x - centerX
            }
        }
        return CGPoint(x: proposedContentOffset.x + adjustOffsetX, y: proposedContentOffset.y)
    }
    
}
