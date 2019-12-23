import UIKit
import MixinServices

class WithdrawalTipWindow: BottomSheetView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var changeButton: RoundedButton!
    @IBOutlet weak var continueButton: UIButton!

    typealias CompletionHandler = (Bool) -> Void

    private var timer: Timer?
    private var canDismiss = false
    private var countDown = 3
    private var completion: CompletionHandler?

    override func awakeFromNib() {
        super.awakeFromNib()
        changeButton.setTitle(R.string.localizable.wallet_withdrawal_change_amount_count("3"), for: .normal)
    }

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

    func render(asset: AssetItem, completion: @escaping CompletionHandler) -> WithdrawalTipWindow {
        self.completion = completion
        titleLabel.text = Localized.WALLET_WITHDRAWAL_ASSET(assetName: asset.symbol)
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownAction), userInfo: nil, repeats: true)
        return self
    }

    @IBAction func changeAmountAction(_ sender: Any) {
        canDismiss = true
        dismissPopupControllerAnimated()
        completion?(false)
    }

    @IBAction func continueAction(_ sender: Any) {
        completion?(true)
        canDismiss = true
        dismissPopupControllerAnimated()
    }

    @objc func countDownAction() {
        countDown -= 1

        if countDown <= 0 {
            timer?.invalidate()
            timer = nil

            UIView.performWithoutAnimation {
                self.changeButton.isEnabled = true
                self.continueButton.isEnabled = true
                self.changeButton.setTitle(R.string.localizable.wallet_withdrawal_change_amount(), for: .normal)
                self.changeButton.layoutIfNeeded()
            }
        } else {
            UIView.performWithoutAnimation { self.changeButton.setTitle(R.string.localizable.wallet_withdrawal_change_amount_count("\(self.countDown)"), for: .normal)
                self.changeButton.layoutIfNeeded()
            }
        }
    }


    class func instance() -> WithdrawalTipWindow {
        return Bundle.main.loadNibNamed("WithdrawalTipWindow", owner: nil, options: nil)?.first as! WithdrawalTipWindow
    }

}
