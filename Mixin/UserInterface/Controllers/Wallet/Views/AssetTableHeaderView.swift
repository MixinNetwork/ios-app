import UIKit

class AssetTableHeaderView: UIView, XibDesignable {
    
    @IBOutlet weak var titleView: AssetTitleView!
    @IBOutlet weak var transactionsHeaderView: UIView!
    @IBOutlet weak var filterButton: UIButton!
    
    @IBOutlet weak var transactionsHeaderTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var transactionsHeaderHeightConstraint: NSLayoutConstraint!
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height = AssetTitleView.height(hasActionButtons: true)
            + transactionsHeaderTopConstraint.constant
            + transactionsHeaderHeightConstraint.constant
        return CGSize(width: size.width, height: height)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
}
