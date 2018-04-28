import UIKit

class LeftAlignedFlowLayout: UICollectionViewFlowLayout {
    
    var layoutAttributes: [UICollectionViewLayoutAttributes]?
    
    override var collectionViewContentSize: CGSize {
        let numberOfItems = CGFloat(collectionView?.numberOfItems(inSection: 0) ?? 0)
        return CGSize(width: sectionInset.left + numberOfItems * itemSize.width + sectionInset.right,
                      height: itemSize.height)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard var attrs = super.layoutAttributesForElements(in: rect) else {
            return nil
        }
        if let layoutAttributes = layoutAttributes {
            return layoutAttributes
        } else {
            for (index, attr) in attrs.enumerated() {
                guard index != 0 else {
                    continue
                }
                let prev = attrs[index - 1]
                attr.frame.origin = CGPoint(x: prev.frame.maxX, y: 0)
            }
            if !attrs.isEmpty {
                layoutAttributes = attrs
            }
            return attrs
        }
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        layoutAttributes = nil
    }
    
}
