import UIKit

class AlignedFlowLayout: UICollectionViewFlowLayout {
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let layoutAttributes = super.layoutAttributesForElements(in: rect)?.map({ $0.copy() }) as? [UICollectionViewLayoutAttributes]
        let attributesList = layoutAttributes?.compactMap { attributes -> UICollectionViewLayoutAttributes? in
            if attributes.representedElementCategory == .cell {
                return layoutAttributesForItem(at: attributes.indexPath)
            }
            return attributes
        }
        return attributesList
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let layoutAttributes = super.layoutAttributesForItem(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }
        if isFirstItemOfALine(layoutAttributes: layoutAttributes) {
            layoutAttributes.frame.origin.x = sectionInset.left
        } else {
            let precedingIndexPath = IndexPath(item: layoutAttributes.indexPath.item - 1, section: layoutAttributes.indexPath.section)
            if let precedingLayoutAttributes = layoutAttributesForItem(at: precedingIndexPath) {
                layoutAttributes.frame.origin.x = precedingLayoutAttributes.frame.maxX + minimumInteritemSpacing
            }
        }
        return layoutAttributes
    }
    
    private func isFirstItemOfALine(layoutAttributes: UICollectionViewLayoutAttributes) -> Bool {
        if layoutAttributes.indexPath.item <= 0 {
            return true
        } else {
            let precedingIndexPath = IndexPath(item: layoutAttributes.indexPath.item - 1, section: layoutAttributes.indexPath.section)
            if let precedingLayoutAttributes = super.layoutAttributesForItem(at: precedingIndexPath), let collectionViewWidth = collectionView?.frame.size.width {
                let lineFrame = CGRect(x: sectionInset.left,
                                       y: layoutAttributes.frame.origin.y,
                                       width: collectionViewWidth - sectionInset.horizontal,
                                       height: layoutAttributes.size.height)
                return !lineFrame.intersects(precedingLayoutAttributes.frame)
            } else {
                return true
            }
        }
    }
    
}
