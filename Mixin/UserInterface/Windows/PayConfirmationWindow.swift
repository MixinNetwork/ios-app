import Foundation
import MixinServices

class PayConfirmationWindow: BottomSheetView {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var mixinIDLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var bigAmountConfirmButton: RoundedButton!
    @IBOutlet weak var bigAmountCancelButton: UIButton!
    @IBOutlet weak var dismissButton: UIButton!


    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    func render(asset: AssetItem, action: PayWindow.PinAction, amount: String, memo: String, error: String? = nil, fiatMoneyAmount: String? = nil, textfield: UITextField? = nil) -> PayConfirmationWindow {
        return self
    }

    static func instance() -> PayConfirmationWindow {
        return Bundle.main.loadNibNamed("PayConfirmationWindow", owner: nil, options: nil)?.first as! PayConfirmationWindow
    }
}
