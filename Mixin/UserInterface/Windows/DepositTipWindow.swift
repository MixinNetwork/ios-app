import UIKit
import MixinServices

class DepositTipWindow: BottomSheetView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tipsLabel: UILabel!
    @IBOutlet weak var warningLabel: UILabel!

    private var canDismiss = false
    private var asset: AssetItem!
    
    override func dismissPopupControllerAnimated() {
        guard canDismiss else {
            return
        }
        super.dismissPopupControllerAnimated()
    }

    func render(asset: AssetItem) -> DepositTipWindow {
        self.asset = asset
        titleLabel.text = "\(asset.symbol) \(Localized.WALLET_DEPOSIT)"
        tipsLabel.text = asset.depositTips
        if !asset.tag.isEmpty {
            warningLabel.text = R.string.localizable.wallet_deposit_account_attention(asset.symbol)
        } else {
            warningLabel.text = R.string.localizable.wallet_deposit_attention()
        }
        return self
    }

    @IBAction func okAction(_ sender: Any) {
        canDismiss = true
        dismissPopupControllerAnimated()
    }

    class func instance() -> DepositTipWindow {
        return Bundle.main.loadNibNamed("DepositTipWindow", owner: nil, options: nil)?.first as! DepositTipWindow
    }

}
