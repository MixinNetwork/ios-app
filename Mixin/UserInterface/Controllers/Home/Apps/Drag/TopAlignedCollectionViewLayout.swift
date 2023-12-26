import UIKit

final class TopAlignedSingleLineCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
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
        modified.frame.origin.y = sectionInset.top
        return modified
    }
    
}
