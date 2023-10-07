import UIKit
import MixinServices

class DeleteAccountVerifyPinWindow: BottomSheetView {
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    
    @IBOutlet weak var pinFieldBottomConstraint: NSLayoutConstraint!
    
    var onSuccess: (() -> Void)?
    private var lastViewWidth: CGFloat = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        pinField.delegate = self
        pinField.becomeFirstResponder()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
    class func instance() -> DeleteAccountVerifyPinWindow {
        R.nib.deleteAccountVerifyPinWindow(withOwner: self)!
    }
    
}

extension DeleteAccountVerifyPinWindow {
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let windowHeight = AppDelegate.current.mainWindow.bounds.height
        pinFieldBottomConstraint.constant = windowHeight - endFrame.origin.y + 120
        layoutIfNeeded()
    }
    
}

extension DeleteAccountVerifyPinWindow: PinFieldDelegate {
    
    func inputFinished(pin: String) {
        pinField.isHidden = true
        activityIndicatorView.isHidden = false
        activityIndicatorView.startAnimating()
        AccountAPI.verify(pin: pin) { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            weakSelf.activityIndicatorView.stopAnimating()
            weakSelf.activityIndicatorView.isHidden = true
            weakSelf.pinField.isHidden = false
            switch result {
            case .success:
                weakSelf.pinField.resignFirstResponder()
                weakSelf.onSuccess?()
                weakSelf.dismissPopupController(animated: true)
            case let .failure(error):
                weakSelf.pinField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description, cancelHandler: { _ in
                        self?.pinField.becomeFirstResponder()
                    })
                }
            }
        }
    }
    
}
