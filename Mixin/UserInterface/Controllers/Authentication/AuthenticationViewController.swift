import UIKit
import MixinServices

final class AuthenticationViewController: UIViewController {
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleStackView: UIStackView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var pinFieldWrapperView: UIView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var validatingIndicator: ActivityIndicatorView!
    @IBOutlet weak var keyboardPlaceholderView: UIView!
    
    @IBOutlet weak var pinFieldWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinFieldTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinFieldHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let intentViewController: AuthenticationIntentViewController
    
    private weak var authenticateWithBiometryButton: UIButton?
    private weak var failureView: UIView?
    
    private var canAuthenticateWithBiometry: Bool {
        guard intentViewController.isBiometryAuthAllowed else {
            return false
        }
        guard AppGroupUserDefaults.Wallet.payWithBiometricAuthentication else {
            return false
        }
        guard let date = AppGroupUserDefaults.Wallet.lastPinVerifiedDate else {
            return false
        }
        return -date.timeIntervalSinceNow < AppGroupUserDefaults.Wallet.biometricPaymentExpirationInterval
    }
    
    private var pinFieldWrapperHeight: CGFloat {
        var height = pinFieldTopConstraint.constant
        height += pinFieldHeightConstraint.constant
        if let button = authenticateWithBiometryButton {
            let topOffset: CGFloat
            switch ScreenHeight.current {
            case .short, .medium:
                topOffset = 8
            case .long:
                topOffset = 20
            case .extraLong:
                topOffset = 40
            }
            height += topOffset
            height += button.intrinsicContentSize.height
        }
        height += pinFieldTopConstraint.constant
        return height
    }
    
    init(intentViewController: AuthenticationIntentViewController) {
        self.intentViewController = intentViewController
        super.init(nibName: R.nib.authenticationView.name, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = PopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        backgroundView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        addChild(intentViewController)
        view.addSubview(intentViewController.view)
        intentViewController.view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        intentViewController.view.setContentHuggingPriority(.defaultLow, for: .vertical)
        intentViewController.view.snp.makeConstraints({ (make) in
            make.top.equalTo(titleStackView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(pinFieldWrapperView.snp.top)
        })
        intentViewController.didMove(toParent: self)
        titleLabel.text = intentViewController.intentTitle
        subtitleLabel.text = intentViewController.intentSubtitle
        if let url = intentViewController.intentSubtitleIconURL {
            let imageView = UIImageView()
            imageView.layer.cornerRadius = 8
            imageView.clipsToBounds = true
            imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            subtitleStackView.insertArrangedSubview(imageView, at: 0)
            imageView.snp.makeConstraints { make in
                make.height.equalTo(imageView.snp.width)
                make.width.equalTo(16)
            }
            imageView.sd_setImage(with: url)
        }
        
        let biometryType = BiometryType.payment
        if canAuthenticateWithBiometry && biometryType != .none {
            let button = UIButton()
            button.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 0)
            button.setTitleColor(.theme, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14)
            switch biometryType {
            case .none:
                assertionFailure()
            case .touchID:
                button.setImage(R.image.ic_pay_touch(), for: .normal)
                button.setTitle(R.string.localizable.touch_id(), for: .normal)
            case .faceID:
                button.setImage(R.image.ic_pay_face(), for: .normal)
                button.setTitle(R.string.localizable.face_id(), for: .normal)
            }
            button.addTarget(self, action: #selector(authenticateWithBiometry(_:)), for: .touchUpInside)
            pinFieldWrapperView.addSubview(button)
            button.snp.makeConstraints { make in
                let bottomOffset: CGFloat
                switch ScreenHeight.current {
                case .short, .medium:
                    bottomOffset = 16
                case .long:
                    bottomOffset = 20
                case .extraLong:
                    bottomOffset = 30
                }
                make.bottom.equalTo(pinFieldWrapperView.snp.bottom).offset(-bottomOffset)
                make.centerX.equalToSuperview()
            }
            
            authenticateWithBiometryButton = button
        }
        
        if intentViewController.inputPINOnAppear {
            pinFieldWrapperView.alpha = 1
            pinFieldWrapperHeightConstraint.constant = pinFieldWrapperHeight
        } else {
            pinFieldWrapperView.alpha = 0
            pinFieldWrapperHeightConstraint.constant = 0
        }
        
        view.layoutIfNeeded()
        
        AppDelegate.current.mainWindow.endEditing(true)
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(keyboardWillAppear),
                           name: UIResponder.keyboardWillShowNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(keyboardWillDisappear),
                           name: UIResponder.keyboardWillHideNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(presentationViewControllerWillDismissPresentedViewController(_:)),
                           name: PopupPresentationController.willDismissPresentedViewControllerNotification,
                           object: nil)
        if intentViewController.inputPINOnAppear {
            pinField.becomeFirstResponder()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.current.mainWindow.endEditing(true)
    }
    
    func beginPINInputting() {
        UIView.animate(withDuration: 0.3) {
            self.pinFieldWrapperView.alpha = 1
            self.pinFieldWrapperHeightConstraint.constant = self.pinFieldWrapperHeight
            self.view.layoutIfNeeded()
            self.pinField.becomeFirstResponder()
        }
    }
    
    func endPINInputting(alongside animation: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3) {
            self.pinFieldWrapperView.alpha = 0
            self.pinFieldWrapperHeightConstraint.constant = 0
            self.pinField.resignFirstResponder()
            animation()
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func presentationViewControllerWillDismissPresentedViewController(_ notification: Notification) {
        guard let controller = notification.object as? PopupPresentationController else {
            return
        }
        guard controller.presentedViewController == self else {
            return
        }
        intentViewController.authenticationViewControllerWillDismiss(self)
    }
    
    private func authenticate(with pin: String) {
        validatingIndicator.startAnimating()
        pinField.isHidden = true
        pinField.receivesInput = false
        authenticateWithBiometryButton?.isHidden = true
        intentViewController.authenticationViewController(self, didInput: pin) { error in
            if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                PINVerificationFailureHandler.handle(error: error) { description in
                    self.layoutForAuthenticationFailure(description: description)
                }
            } else if let error {
                self.layoutForAuthenticationFailure(description: error.localizedDescription)
            } else {
                self.validatingIndicator.stopAnimating()
            }
        }
    }
    
    private func layoutForAuthenticationFailure(description: String) {
        let failureView = R.nib.authenticationFailureView(owner: nil)!
        failureView.label.text = description
        failureView.tryAgainButton.addTarget(self, action: #selector(self.tryAgain(_:)), for: .touchUpInside)
        self.view.addSubview(failureView)
        failureView.snp.makeConstraints { make in
            make.top.equalTo(self.pinFieldWrapperView.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }
        self.failureView = failureView
        self.view.layoutIfNeeded()
        self.validatingIndicator.stopAnimating()
        
        UIView.animate(withDuration: 0.3) {
            self.pinField.resignFirstResponder()
            self.pinFieldWrapperHeightConstraint.priority = .almostInexist
            failureView.snp.makeConstraints { make in
                let failureViewBottomOffset: CGFloat
                if self.view.safeAreaInsets.bottom > 0 {
                    failureViewBottomOffset = 0
                } else {
                    failureViewBottomOffset = 20
                }
                make.bottom.equalTo(self.keyboardPlaceholderView.snp.top).offset(-failureViewBottomOffset)
            }
            self.view.layoutIfNeeded()
        }
    }
    
}

// MARK: - Actions
extension AuthenticationViewController {
    
    @IBAction func close(_ sender: Any) {
        intentViewController.authenticationViewControllerWillDismiss(self)
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func authenticateWithPINField(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        authenticate(with: pinField.text)
    }
    
    @objc private func authenticateWithBiometry(_ sender: Any) {
        pinField.receivesInput = false
        let prompt = R.string.localizable.authorize_payment_via(BiometryType.payment.localizedName)
        DispatchQueue.global().async {
            DispatchQueue.main.sync {
                ScreenLockManager.shared.hasOtherBiometricAuthInProgress = true
            }
            guard let pin = Keychain.shared.getPIN(prompt: prompt) else {
                DispatchQueue.main.sync {
                    ScreenLockManager.shared.hasOtherBiometricAuthInProgress = false
                    self.pinField.receivesInput = true
                }
                return
            }
            DispatchQueue.main.sync {
                ScreenLockManager.shared.hasOtherBiometricAuthInProgress = false
                self.authenticate(with: pin)
            }
        }
    }
    
    @objc private func tryAgain(_ sender: Any) {
        pinField.clear()
        pinField.isHidden = false
        pinField.receivesInput = true
        authenticateWithBiometryButton?.isHidden = false
        failureView?.removeFromSuperview()
        pinFieldWrapperHeightConstraint.priority = .almostRequired
        UIView.animate(withDuration: 0.3) {
            self.pinField.becomeFirstResponder()
            self.view.layoutIfNeeded()
        }
    }
    
}

// MARK: - Keyboard
extension AuthenticationViewController {
    
    @objc private func keyboardWillAppear(_ sender: Notification) {
        guard
            let info = sender.userInfo,
            let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
            let animation = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        else {
            return
        }
        let options = UIView.AnimationOptions(rawValue: UInt(animation << 16))
        if let keyboard = pinField.inputView as? NumberPadView {
            keyboardPlaceholderHeightConstraint.constant = keyboard.intrinsicContentSize.height
        }
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: options,
                       animations: view.layoutIfNeeded,
                       completion: nil)
    }
    
    @objc private func keyboardWillDisappear(_ sender: Notification) {
        guard
            let info = sender.userInfo,
            let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
            let animation = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        else {
            return
        }
        let options = UIView.AnimationOptions(rawValue: UInt(animation << 16))
        keyboardPlaceholderHeightConstraint.constant = 0
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: options,
                       animations: view.layoutIfNeeded,
                       completion: nil)
    }
    
}
