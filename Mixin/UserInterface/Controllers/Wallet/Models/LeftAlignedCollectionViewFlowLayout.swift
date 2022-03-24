import UIKit

class LeftAlignedCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        super.layoutAttributesForElements(in: rect)?.compactMap { attributes in
            if attributes.representedElementCategory == .cell {
                return modifiedCopy(of: attributes)
            } else {
                return attributes
            }
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if let attributes = super.layoutAttributesForItem(at: indexPath) {
            return modifiedCopy(of: attributes)
        } else {
            return nil
        }
    }
    
    private func modifiedCopy(of original: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes? {
        guard let modified = original.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }
        
        let precedingAttributes: UICollectionViewLayoutAttributes?
        if original.indexPath.item == 0 {
            precedingAttributes = nil
        } else {
            let indexPath = IndexPath(item: original.indexPath.item - 1, section: original.indexPath.section)
            precedingAttributes = layoutAttributesForItem(at: indexPath)
        }
        
        let isFirstItemOfTheRow: Bool
        if original.indexPath.item == 0 {
            isFirstItemOfTheRow = true
        } else if let precedingAttributes = precedingAttributes {
            isFirstItemOfTheRow = abs(original.center.y - precedingAttributes.center.y) > 1
        } else {
            isFirstItemOfTheRow = false
        }
        
        if isFirstItemOfTheRow {
            modified.frame.origin.x = sectionInset.left
        } else if let precedingAttributes = precedingAttributes {
            modified.frame.origin.x = precedingAttributes.frame.maxX + minimumInteritemSpacing
        }
        return modified
    }
    
}
