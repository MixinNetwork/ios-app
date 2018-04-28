import UIKit
import LocalAuthentication
import SwiftMessages
import Alamofire

class DAppPayWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!
        
    private weak var textfield: UITextField?

    private let payView = DAppPayView.instance()

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(payView)
        payView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    static let shared = Bundle.main.loadNibNamed("DAppPayWindow", owner: nil, options: nil)?.first as! DAppPayWindow

    func presentPopupControllerAnimated(asset: AssetItem, user: UserItem? = nil, address: Address? = nil, amount: String, memo: String, trackId: String, textfield: UITextField?) {
        guard !isShowing else {
            return
        }
        self.textfield = textfield
        super.presentPopupControllerAnimated()
        payView.render(asset: Asset.createAsset(asset: asset), user: user, address: address, amount: amount, memo: memo, trackId: trackId, superView: self)
    }

    override func dismissPopupControllerAnimated() {
        if payView.transfering {
            return
        }
        super.dismissPopupControllerAnimated()
        textfield?.becomeFirstResponder()
    }

}

