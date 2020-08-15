import Foundation
import MixinServices

class DuplicateConfirmationWindow: BottomSheetView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tipsLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var confirmButton: RoundedButton!

    private var asset: AssetItem!
    private var amount = ""
    private var memo = ""
    private var pinAction: PayWindow.PinAction!

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    func render(traceCreatedAt: String, asset: AssetItem, action: PayWindow.PinAction, amount: String, memo: String, error: String? = nil, fiatMoneyAmount: String? = nil, textfield: UITextField? = nil) -> DuplicateConfirmationWindow {

        let amountToken = CurrencyFormatter.localizedString(from: amount, locale: .current, format: .precision, sign: .whenNegative, symbol: .custom(asset.symbol)) ?? amount
        let amountExchange = CurrencyFormatter.localizedPrice(price: amount, priceUsd: asset.priceUsd)
        if let fiatMoneyAmount = fiatMoneyAmount {
            amountLabel.text = fiatMoneyAmount + " " + Currency.current.code
            amountExchangeLabel.text = amountToken
        } else {
            amountLabel.text = amountToken
            amountExchangeLabel.text = amountExchange
        }

        switch action {
        case let .transfer(_, user, _):
            titleLabel.text = R.string.localizable.transfer_duplicate_title()
            tipsLabel.text = R.string.localizable.transfer_duplicate_prompt(amountLabel.text ?? "", user.fullName, traceCreatedAt.toUTCDate().simpleTimeAgo())
        case let .withdraw(_, address, _, _):
            titleLabel.text = R.string.localizable.withdraw_duplicate_title()
            tipsLabel.text = R.string.localizable.withdraw_duplicate_prompt(amountLabel.text ?? "", address.fullAddress.toSimpleKey(), traceCreatedAt.toUTCDate().simpleTimeAgo())
        default:
            break
        }

        assetIconView.setIcon(asset: asset)
        return self
    }

    static func instance() -> DuplicateConfirmationWindow {
        return Bundle.main.loadNibNamed("DuplicateConfirmationWindow", owner: nil, options: nil)?.first as! DuplicateConfirmationWindow
    }
}
