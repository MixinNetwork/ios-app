import UIKit

class StackedPhotoLayout: UICollectionViewLayout {
    
    let visibleItemCount: Int = 4
    
    private let itemSize = CGSize(width: 210, height: 280)
    private let itemScale: CGFloat = 0.95
    private let itemRotationDegree: CGFloat = 4
    
    private var contentWidth: CGFloat = 0
    private var layoutAttributes = [UICollectionViewLayoutAttributes]()
    
    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else {
            layoutAttributes = []
            return
        }
        let numberOfItems = collectionView.numberOfItems(inSection: 0)
        layoutAttributes = (0 ..< numberOfItems).map { index in
            let itemAttributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
            if index < visibleItemCount {
                let angle = itemRotationDegree * .pi / 180 * CGFloat(index)
                let scale = pow(itemScale, CGFloat(index))
                itemAttributes.transform = CGAffineTransform(scaleX: scale, y: scale).rotated(by: angle)
                itemAttributes.zIndex = -index
                itemAttributes.frame = CGRect(origin: .zero, size: itemSize)
                if index == min(numberOfItems, visibleItemCount) - 1 {
                    contentWidth = ceil(itemSize.width + itemSize.height * scale * sin(angle))
                }
            } else {
                itemAttributes.isHidden = true
                itemAttributes.frame = .zero
            }
            return itemAttributes
        }
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
    
    override var collectionViewContentSize: CGSize {
        CGSize(width: contentWidth, height: itemSize.height)
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        layoutAttributes.filter { $0.frame.intersects(rect) }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < layoutAttributes.count else {
            return nil
        }
        return layoutAttributes[indexPath.row]
    }
    
}
