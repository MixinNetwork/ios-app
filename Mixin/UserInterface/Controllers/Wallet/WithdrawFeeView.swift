import UIKit

final class WithdrawFeeView: UIView, XibDesignable {
    
    @IBOutlet weak var networkLabel: UILabel!
    @IBOutlet weak var minimumWithdrawalLabel: UILabel!
    @IBOutlet weak var networkFeeLabel: UILabel!
    @IBOutlet weak var switchFeeDisclosureIndicatorView: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
}
