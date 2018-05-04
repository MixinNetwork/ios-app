import UIKit

class HorizontalSingleLineFlowLayout: UICollectionViewLayout {
    
    @IBInspectable var leftMargin: CGFloat = 10
    @IBInspectable var rightMargin: CGFloat = 10
    @IBInspectable var itemWidth: CGFloat = 88
    @IBInspectable var itemHeight: CGFloat = 101
    
    private var cache = [IndexPath: UICollectionViewLayoutAttributes]()
    
    override var collectionViewContentSize: CGSize {
        if let collectionView = collectionView {
            let width = Array(0...collectionView.numberOfSections - 1).reduce(0) {
                $0 + CGFloat(collectionView.numberOfItems(inSection: $1)) * itemWidth
            }
            return CGSize(width: width + leftMargin + rightMargin, height: itemHeight)
        } else {
            return CGSize(width: 375, height: itemHeight)
        }
    }
    
    override func prepare() {
        guard cache.isEmpty, let collectionView = collectionView else {
            return
        }
        var x = leftMargin
        for section in 0..<collectionView.numberOfSections {
            for item in 0..<collectionView.numberOfItems(inSection: section) {
                let indexPath = IndexPath(item: item, section: section)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = CGRect(x: x, y: 0, width: itemWidth, height: itemHeight)
                cache[indexPath] = attributes
                x += itemWidth
            }
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.values.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath]
    }
    
}
