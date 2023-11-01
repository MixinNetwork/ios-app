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

    override func dismissPopupController(animated: Bool) {
        guard canDismiss else {
            return
        }
        super.dismissPopupController(animated: animated)
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
    
    func render(token: TokenItem, tokenAmount: Decimal, fiatMoneyAmount: Decimal, memo: String, completion: @escaping CompletionHandler) {
        self.completion = completion
        
        amountLabel.text = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .whenNegative, symbol: .custom(token.symbol))
        amountExchangeLabel.text = "≈ " + Currency.current.symbol + CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never)
        
        assetIconView.setIcon(token: token)
        memoLabel.isHidden = memo.isEmpty
        memoPlaceView.isHidden = memo.isEmpty
        memoLabel.text = memo
        
        initTimer()
    }
    
    func initTimer() {
        confirmButton.setTitle("\(R.string.localizable.continue())(\(self.countDown))", for: .normal)
        confirmButton.isEnabled = false
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownAction), userInfo: nil, repeats: true)
    }

    @IBAction func continueAction(_ sender: Any) {
        canDismiss = true
        completion?(true, nil)
        dismissPopupController(animated: true)
    }

    @IBAction func dismissAction(_ sender: Any) {
        canDismiss = true
        completion?(false, nil)
        dismissPopupController(animated: true)
    }

    @objc func countDownAction() {
        countDown -= 1

        if countDown <= 0 {
            timer?.invalidate()
            timer = nil

            UIView.performWithoutAnimation {
                self.confirmButton.isEnabled = true
                self.confirmButton.setTitle(R.string.localizable.continue(), for: .normal)
                self.confirmButton.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation {
                self.confirmButton.setTitle("\(R.string.localizable.continue())(\(self.countDown))", for: .normal)
                self.confirmButton.layoutIfNeeded()
            }
        }
    }
}
