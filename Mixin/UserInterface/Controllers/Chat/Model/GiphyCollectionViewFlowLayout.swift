import UIKit

class GiphyCollectionViewFlowLayout: TilingCollectionViewFlowLayout {
    
    @IBInspectable var footerHeight: CGFloat = 60
    
    override func prepare() {
        super.prepare()
        if let collectionView = collectionView {
            footerReferenceSize = CGSize(width: collectionView.bounds.width, height: footerHeight)
        }
    }
    
}
