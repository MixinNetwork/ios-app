import UIKit

class StackedPhotoLayout: UICollectionViewLayout {
    
    var itemSize: CGSize = CGSize(width: 210, height: 280)  {
        didSet {
            guard itemSize != oldValue else {
                return
            }
            invalidateLayout()
        }
    }
    var itemScale: CGFloat = 0.95 {
        didSet {
            guard itemScale != oldValue else {
                return
            }
            invalidateLayout()
        }
    }
    var itemRotationDegree: CGFloat = 4 {
        didSet {
            guard itemRotationDegree != oldValue else {
                return
            }
            invalidateLayout()
        }
    }
    var visibleItemCount: Int = 4 {
        didSet {
            guard visibleItemCount != oldValue else {
                return
            }
            invalidateLayout()
        }
    }
    
    private var contentWidth: CGFloat = 0
    private var layoutAttributes = [UICollectionViewLayoutAttributes]()

    class func intrinsicContentSize(
        itemSize: CGSize,
        itemScale: CGFloat,
        itemRotationDegree: CGFloat,
        itemCount: Int
    ) -> CGSize {
        let angle = itemRotationDegree * .pi / 180 * CGFloat(itemCount - 1)
        let scale = pow(itemScale, CGFloat(itemCount - 1))
        let width = ceil(itemSize.width + itemSize.height * scale * sin(angle))
        return CGSize(width: width, height: itemSize.height)
    }
    
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
                var transform3D = CATransform3DIdentity
                transform3D = CATransform3DRotate(transform3D, angle, 0, 0, 1)
                transform3D = CATransform3DScale(transform3D, scale, scale, 1)
                itemAttributes.transform3D = transform3D
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
