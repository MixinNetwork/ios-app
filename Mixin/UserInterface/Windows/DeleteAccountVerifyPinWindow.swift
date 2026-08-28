import UIKit
import MixinServices

final class DeleteAccountVerifyPinWindow: UIViewController {
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var pinFieldBottomConstraint: NSLayoutConstraint!
    
    var onSuccess: (() -> Void)?
    
    init(onSuccess: (() -> Void)? = nil) {
        self.onSuccess = onSuccess
        let nib = R.nib.deleteAccountVerifyPinWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        pinField.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pinField.becomeFirstResponder()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        dismiss(animated: true)
    }
    
}

extension DeleteAccountVerifyPinWindow {
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let screenHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height
        pinFieldBottomConstraint.constant = max(0, screenHeight - endFrame.origin.y) + 120
        view.layoutIfNeeded()
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
                let onSuccess = weakSelf.onSuccess
                weakSelf.dismiss(animated: true) {
                    onSuccess?()
                }
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
