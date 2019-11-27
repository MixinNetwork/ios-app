import UIKit

class LargeTransferConfirmationWindow: BottomSheetView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var fiatMoneyValueLabel: UILabel!
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    var onConfirm: (() -> Void)?
    
    private var countdown = 3
    
    private weak var timer: Timer?
    
    deinit {
        timer?.invalidate()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        continueButton.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 16, weight: .regular)
        updateContinueButton()
    }
    
    override func presentPopupControllerAnimated() {
        super.presentPopupControllerAnimated()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (timer) in
            guard let self = self else {
                return
            }
            self.countdown -= 1
            self.updateContinueButton()
            if self.countdown <= 0 {
                timer.invalidate()
            }
        }
    }
    
    @IBAction func continueAction(_ sender: Any) {
        onConfirm?()
        dismissPopupControllerAnimated()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    func load(asset: AssetItem, amount: String, amountIsAsset: Bool, receiver: String) {
        assetIconView.setIcon(asset: asset)
        let fiatMoneyPrice = asset.priceUsd.doubleValue * Currency.current.rate
        let fiatMoneyValue: Double
        if amountIsAsset {
            fiatMoneyValue = amount.doubleValue * fiatMoneyPrice
            amountLabel.text = amount + " " + asset.symbol
        } else {
            fiatMoneyValue = amount.doubleValue
            amountLabel.text = CurrencyFormatter.localizedString(from: fiatMoneyValue / fiatMoneyPrice, format: .precision, sign: .never, symbol: .custom(asset.symbol))
        }
        let localizedFiatMoenyValue = CurrencyFormatter.localizedString(from: fiatMoneyValue, format: .fiatMoney, sign: .never, symbol: .currentCurrency) ?? ""
        fiatMoneyValueLabel.text = localizedFiatMoenyValue
        promptLabel.text = R.string.localizable.transfer_large_prompt(asset.symbol, localizedFiatMoenyValue, receiver)
    }
    
    private func updateContinueButton() {
        var title = R.string.localizable.action_continue()
        if countdown > 0 {
            title += " (\(countdown))"
            continueButton.isEnabled = false
        } else {
            continueButton.isEnabled = true
        }
        UIView.performWithoutAnimation {
            continueButton.setTitle(title, for: .normal)
            continueButton.layoutIfNeeded()
        }
    }
    
}
