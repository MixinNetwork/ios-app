import UIKit

final class OpenTradeOrderHeaderView: UICollectionReusableView {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var label: UILabel!
    
    var onShowOrders: ((UIView) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.layer.masksToBounds = true
        label.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    @IBAction func showOrders(_ sender: UIButton) {
        onShowOrders?(self)
    }
    
}
