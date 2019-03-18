import UIKit
import LocalAuthentication
import Alamofire

class PayWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!
    
    var onDismiss: (() -> Void)?
    
    private weak var textfield: UITextField?

    private let payView = PayView.instance()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(payView)
        payView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    static let shared = Bundle.main.loadNibNamed("PayWindow", owner: nil, options: nil)?.first as! PayWindow

    func presentPopupControllerAnimated(asset: AssetItem, user: UserItem? = nil, address: Address? = nil, amount: String, memo: String, trackId: String, amountUsd: String? = nil, textfield: UITextField?) {
        guard !isShowing else {
            return
        }
        self.textfield = textfield
        super.presentPopupControllerAnimated()
        payView.render(asset: asset, user: user, address: address, amount: amount, memo: memo, trackId: trackId, amountUsd: amountUsd, superView: self)
    }

    override func dismissPopupControllerAnimated() {
        if payView.processing {
            return
        }
        super.dismissPopupControllerAnimated()
        textfield?.becomeFirstResponder()
        onDismiss?()
    }

}

