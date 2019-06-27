import UIKit

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
        if asset.isAccount {
            warningLabel.text = R.string.localizable.wallet_deposit_account_notice(asset.symbol)
            warningLabel.isHidden = false
        } else {
            warningLabel.isHidden = true
        }
        return self
    }

    @IBAction func okAction(_ sender: Any) {
        canDismiss = true
        dismissPopupControllerAnimated()
    }

    @IBAction func dontRemindAction(_ sender: Any) {
        guard let assetId = asset?.chainId else {
            return
        }
        WalletUserDefault.shared.depositTipRemind.removeAll( where: { $0 == assetId })
        WalletUserDefault.shared.depositTipRemind.append(assetId)

        canDismiss = true
        dismissPopupControllerAnimated()
    }

    class func instance() -> DepositTipWindow {
        return Bundle.main.loadNibNamed("DepositTipWindow", owner: nil, options: nil)?.first as! DepositTipWindow
    }

}
