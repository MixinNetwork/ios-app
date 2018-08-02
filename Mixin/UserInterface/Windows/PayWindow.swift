import UIKit
import LocalAuthentication
import SwiftMessages
import Alamofire

class PayWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!
        
    private weak var textfield: UITextField?

    private let payView = PayView.instance()

    override var endEditingWhenPresented: Bool {
        return false
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(payView)
        payView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    static let shared = Bundle.main.loadNibNamed("PayWindow", owner: nil, options: nil)?.first as! PayWindow

    func presentPopupControllerAnimated(isTransfer: Bool, asset: AssetItem, user: UserItem? = nil, address: Address? = nil, amount: String, memo: String, trackId: String, textfield: UITextField?) {
        guard !isShowing else {
            return
        }
        self.textfield = textfield
        super.presentPopupControllerAnimated()
        payView.render(isTransfer: isTransfer, asset: asset, user: user, address: address, amount: amount, memo: memo, trackId: trackId, superView: self)
    }

    override func dismissPopupControllerAnimated() {
        if payView.processing {
            return
        }
        self.alpha = 1.0
        isShowing = false
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.popupView.center = self.getAnimationStartPoint()
        }, completion: { (finished: Bool) -> Void in
            self.removeFromSuperview()
            self.textfield?.becomeFirstResponder()
        })
    }

}

