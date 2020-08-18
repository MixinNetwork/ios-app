import Foundation
import MixinServices

class AssetConfirmationWindow: BottomSheetView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tipsLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var amountExchangeLabel: UILabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var confirmButton: RoundedButton!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var memoPlaceView: UIView!

    private var canDismiss = false
    private var timer: Timer?
    private var countDown = 3
    var completion: CompletionHandler?

    typealias CompletionHandler = (Bool, String?) -> Void

    deinit {
        timer?.invalidate()
        timer = nil
    }

    override func dismissPopupControllerAnimated() {
        guard canDismiss else {
            return
        }
        super.dismissPopupControllerAnimated()
    }

    func render(asset: AssetItem, amount: String, memo: String, fiatMoneyAmount: String? = nil, completion: @escaping CompletionHandler) -> BottomSheetView {
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

        assetIconView.setIcon(asset: asset)
        memoLabel.isHidden = memo.isEmpty
        memoPlaceView.isHidden = memo.isEmpty
        memoLabel.text = memo

        initTimer()
        return self
    }

    func initTimer() {
        confirmButton.setTitle("\(R.string.localizable.action_continue())(\(self.countDown))", for: .normal)
        confirmButton.isEnabled = false
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownAction), userInfo: nil, repeats: true)
    }

    @IBAction func continueAction(_ sender: Any) {
        canDismiss = true
        completion?(true, nil)
        dismissPopupControllerAnimated()
    }

    @IBAction func dismissAction(_ sender: Any) {
        canDismiss = true
        completion?(false, nil)
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
}
