import UIKit

class TilingCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    @IBInspectable var numberOfItemsPerRow: Int = 3
    @IBInspectable var spacing: CGFloat = 8
    
    required init(numberOfItemsPerRow: Int, spacing: CGFloat) {
        self.numberOfItemsPerRow = numberOfItemsPerRow
        self.spacing = spacing
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else {
            return
        }
        let numberOfItemsPerRow = CGFloat(self.numberOfItemsPerRow)
        sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        let layoutWidth = collectionView.bounds.width - sectionInset.horizontal
        let itemWidth = floor((layoutWidth - (numberOfItemsPerRow - 1) * spacing) / numberOfItemsPerRow)
        itemSize = CGSize(width: itemWidth, height: itemWidth)
        minimumLineSpacing = spacing
        minimumInteritemSpacing = spacing
        if #available(iOS 11.0, *) {
            sectionInsetReference = .fromSafeArea
        }
    }
    
}
