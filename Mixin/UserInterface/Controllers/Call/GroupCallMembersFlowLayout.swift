import UIKit

class GroupCallMembersFlowLayout: UICollectionViewFlowLayout {
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect) else {
            return nil
        }
        guard let collectionView = collectionView else {
            return superAttributes
        }
        let attributes = NSArray(array: superAttributes, copyItems: true)
        
        var firstRow = [UICollectionViewLayoutAttributes]()
        attributes.enumerateObjects { (attribute, index, stop) in
            guard let attribute = attribute as? UICollectionViewLayoutAttributes else {
                return
            }
            let inFirstRow: Bool
            if let previousAttribute = firstRow.last {
                if abs(previousAttribute.center.y - attribute.center.y) < 1 {
                    inFirstRow = true
                } else {
                    inFirstRow = false
                }
            } else {
                inFirstRow = true
            }
            if inFirstRow {
                firstRow.append(attribute)
            } else {
                stop.pointee = ObjCBool(true)
            }
        }
        
        if attributes.count > 0, attributes.count == firstRow.count {
            let firstAttribute = attributes.firstObject as! UICollectionViewLayoutAttributes
            let lastAttribute = attributes.lastObject as! UICollectionViewLayoutAttributes
            let leftMargin = firstAttribute.frame.origin.x
            let rightMargin = collectionView.bounds.width - lastAttribute.frame.maxX
            let diff = (rightMargin - leftMargin) / 2
            if diff > 1 {
                firstRow.forEach { (attribute) in
                    attribute.center.x += diff
                }
            }
        }
        
        return [UICollectionViewLayoutAttributes](_immutableCocoaArray: attributes)
    }
    
}
