import Foundation
import UIKit

class PinTipsView: BottomSheetView {

    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errorButton: UIButton!
    @IBOutlet weak var passwordView: UIView!

    private var tips: String!
    private var successCallback: ((String) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        pinField.delegate = self
        loadingView.isHidden = true
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }

    override func presentPopupControllerAnimated() {
        UIApplication.currentActivity()?.view.endEditing(true)
        guard !isShowing, let window = UIApplication.shared.keyWindow else {
            return
        }
        descriptionLabel.text = tips
        isShowing = true
        self.frame = window.bounds
        pinField.becomeFirstResponder()
        window.addSubview(self)
    }

    @IBAction func closeAction(_ sender: Any) {
        UIApplication.rootNavigationController()?.popViewController(animated: true)
        dismissPopupControllerAnimated()
    }
    

    @objc func keyboardWillChangeFrame(_ sender: Notification) {
        guard let info = sender.userInfo else {
            return
        }
        guard let duration = (info[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else {
            return
        }
        guard let endKeyboardRect = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        guard isVisibleInScreen else {
            return
        }

        let targetConstraint: CGFloat
        let targetAlpha: CGFloat
        let bounds = UIScreen.main.bounds
        if endKeyboardRect.origin.y == bounds.height || endKeyboardRect.origin.y == bounds.width {
            targetConstraint = 0
            targetAlpha = 0
            self.alpha = 1
        } else {
            targetConstraint = endKeyboardRect.height
            targetAlpha = 1
            self.alpha = 0
        }

        UIView.animate(withDuration: duration, animations: {
            if self.errorView.isHidden {
                self.alpha = targetAlpha
            }
            self.contentBottomConstraint.constant = targetConstraint
            self.layoutIfNeeded()
        }) { (finished) in
            guard finished else {
                return
            }
            if targetConstraint == 0 && self.errorView.isHidden {
                self.removeFromSuperview()
            }
        }
    }

    class func instance(tips: String = Localized.WALLET_PIN_TIPS_DESCRIPTION, successCallback: ((String) -> Void)? = nil) -> PinTipsView {
        let view =  Bundle.main.loadNibNamed("PinTipsView", owner: nil, options: nil)?.first as! PinTipsView
        view.tips = tips
        view.successCallback = successCallback
        return view
    }
}

extension PinTipsView: PinFieldDelegate {

    func inputFinished(pin: String) {
        loadingView.startAnimating()
        loadingView.isHidden = false
        pinField.isHidden = true
        AccountAPI.shared.verify(pin: pin) { [weak self](result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.loadingView.stopAnimating()
            weakSelf.loadingView.isHidden = true
            switch result {
            case .success:
                if WalletUserDefault.shared.checkPinInterval < WalletUserDefault.shared.checkMaxInterval {
                    WalletUserDefault.shared.checkPinInterval *= 2
                }
                WalletUserDefault.shared.lastInputPinTime = Date().timeIntervalSince1970
                weakSelf.successCallback?(pin)
                weakSelf.pinField.resignFirstResponder()
            case let .failure(error):
                if error.code == 429 {
                    weakSelf.pinField.clear()
                    weakSelf.passwordView.isHidden = true
                    weakSelf.descriptionLabel.isHidden = true
                    weakSelf.errorView.isHidden = false
                    weakSelf.errorButton.isHidden = false
                    weakSelf.pinField.resignFirstResponder()
                } else {
                    weakSelf.pinField.clear()
                    weakSelf.pinField.isHidden = false
                    weakSelf.descriptionLabel.textColor = UIColor.red
                    weakSelf.descriptionLabel.text = error.localizedDescription
                }
            }
        }
    }

}
