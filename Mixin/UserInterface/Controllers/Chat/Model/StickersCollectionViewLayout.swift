import UIKit

class StickersCollectionViewFlowLayout: UICollectionViewFlowLayout {
    
    @IBInspectable var numberOfItemsPerRow: Int = 3
    
    init(numberOfItemsPerRow: Int) {
        self.numberOfItemsPerRow = numberOfItemsPerRow
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
        let spacing: CGFloat = 8
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
