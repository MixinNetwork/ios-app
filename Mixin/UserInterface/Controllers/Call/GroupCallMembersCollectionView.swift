import UIKit

class GroupCallMembersCollectionView: UICollectionView {
    
    override var intrinsicContentSize: CGSize {
        contentSize
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != contentSize {
            invalidateIntrinsicContentSize()
        }
    }
    
}
