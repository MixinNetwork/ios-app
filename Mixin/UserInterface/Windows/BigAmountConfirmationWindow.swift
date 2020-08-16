import Foundation
import MixinServices

class BigAmountConfirmationWindow: BottomSheetView {

    @IBOutlet weak var tipsLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var confirmButton: RoundedButton!

    private var timer: Timer?
    private var countDown = 3
    private var completion: CompletionHandler?

    typealias CompletionHandler = (Bool) -> Void

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func render(asset: AssetItem, user: UserItem, amount: String, memo: String, fiatMoneyAmount: String? = nil, fromWeb: Bool, completion: @escaping CompletionHandler) -> BigAmountConfirmationWindow {
        self.completion = completion

        let amountToken = CurrencyFormatter.localizedString(from: amount, locale: .current, format: .precision, sign: .whenNegative, symbol: .custom(asset.symbol)) ?? amount
        let amountExchange = CurrencyFormatter.localizedPrice(price: amount, priceUsd: asset.priceUsd)
        if let fiatMoneyAmount = fiatMoneyAmount {
            amountLabel.text = fiatMoneyAmount + " " + Currency.current.code
            amountExchangeLabel.text = amountToken
        } else {
            amountLabel.text = amountToken
            amountExchangeLabel.text = amountExchange
        }

        tipsLabel.text = R.string.localizable.transfer_large_prompt(amountExchangeLabel.text ?? "", asset.symbol, user.fullName)

        assetIconView.setIcon(asset: asset)

        confirmButton.setTitle("\(R.string.localizable.action_continue())(\(self.countDown))", for: .normal)
        confirmButton.isEnabled = false
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownAction), userInfo: nil, repeats: true)
        return self
    }

    @IBAction func continueAction(_ sender: Any) {
        completion?(true)
        dismissPopupControllerAnimated()
    }

    @IBAction func dismissAction(_ sender: Any) {
        completion?(false)
        dismissPopupControllerAnimated()
    }

    @objc func countDownAction() {
        countDown -= 1

        if countDown <= 0 {
            timer?.invalidate()
            timer = nil

            UIView.performWithoutAnimation {
                self.confirmButton.isEnabled = true
                self.confirmButton.setTitle(R.string.localizable.action_continue(), for: .normal)
                self.confirmButton.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation {
                self.confirmButton.setTitle("\(R.string.localizable.action_continue())(\(self.countDown))", for: .normal)
                self.confirmButton.layoutIfNeeded()
            }
        }
    }

    static func instance() -> BigAmountConfirmationWindow {
        return Bundle.main.loadNibNamed("BigAmountConfirmationWindow", owner: nil, options: nil)?.first as! BigAmountConfirmationWindow
    }
}
