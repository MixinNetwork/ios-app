import UIKit
import MixinServices

final class AuthenticationViewController: UIViewController {
    
    enum RetryAction {
        case notAllowed
        case inputPINAgain
        case custom(() -> Void)
    }
    
    enum AuthenticationResult {
        case success
        case failure(error: Error, retry: RetryAction)
    }
    
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleStackView: UIStackView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var pinFieldWrapperView: UIView!
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var validatingIndicator: ActivityIndicatorView!
    @IBOutlet weak var keyboardPlaceholderView: UIView!
    
    @IBOutlet weak var titleViewHeightConstraint: ScreenHeightCompatibleLayoutConstraint!
    @IBOutlet weak var pinFieldWrapperHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinFieldTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var pinFieldHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let intent: AuthenticationIntent
    private let presentationManager: any UIViewControllerTransitioningDelegate
    
    private weak var titleImageView: UIImageView?
    private weak var subtitleImageView: AvatarImageView?
    private weak var authenticateWithBiometryButton: UIButton?
    private weak var failureView: UIView?
    
    private var customTryAgainAction: (() -> Void)?
    
    private var canAuthenticateWithBiometry: Bool {
        guard intent.options.contains(.allowsBiometricAuthentication) else {
            return false
        }
        guard AppGroupUserDefaults.Wallet.payWithBiometricAuthentication else {
            return false
        }
        guard let date = AppGroupUserDefaults.Wallet.lastPINVerifiedDate else {
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
    
    init(intent: AuthenticationIntent) {
        self.intent = intent
        self.presentationManager = if intent.options.contains(.blurBackground) {
            PinValidationPresentationManager()
        } else {
            PopupPresentationManager()
        }
        super.init(nibName: R.nib.authenticationView.name, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = presentationManager
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
        
        if let intentViewController = intent as? UIViewController {
            addChild(intentViewController)
            view.addSubview(intentViewController.view)
            intentViewController.view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            intentViewController.view.setContentHuggingPriority(.defaultLow, for: .vertical)
            if intent.options.contains(.viewUnderPINField) {
                titleStackView.snp.makeConstraints { make in
                    make.bottom.equalTo(pinFieldWrapperView.snp.top)
                }
            } else {
                pinFieldWrapperView.snp.makeConstraints { make in
                    make.bottom.equalTo(keyboardPlaceholderView.snp.top)
                        .offset(-10)
                        .priority(.almostRequired)
                }
            }
            intentViewController.view.snp.makeConstraints({ (make) in
                make.leading.trailing.equalToSuperview()
                if intent.options.contains(.viewUnderPINField) {
                    make.top.equalTo(pinFieldWrapperView.snp.bottom)
                    make.bottom.equalTo(keyboardPlaceholderView.snp.top)
                        .offset(-10)
                        .priority(.almostRequired)
                } else {
                    make.top.equalTo(titleStackView.snp.bottom)
                    make.bottom.equalTo(pinFieldWrapperView.snp.top)
                }
            })
            intentViewController.didMove(toParent: self)
        } else {
            titleStackView.snp.makeConstraints { make in
                make.bottom.equalTo(pinFieldWrapperView.snp.top)
            }
            pinFieldWrapperView.snp.makeConstraints { make in
                make.bottom.equalTo(keyboardPlaceholderView.snp.top)
                    .offset(-10)
                    .priority(.almostRequired)
            }
        }
        
        if intent.options.contains(.unskippable) {
            closeButton.isHidden = true
            titleViewHeightConstraint.constant = 30
        }
        reloadTitleView()
        
        let biometryType = BiometryType.payment
        if canAuthenticateWithBiometry && biometryType != .none {
            let button = UIButton(type: .system)
            button.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -12, bottom: 0, right: 0)
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
        
        if intent.options.contains(.becomesFirstResponderOnAppear) {
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
                           name: BackgroundDismissablePopupPresentationController.willDismissPresentedViewControllerNotification,
                           object: nil)
        if intent.options.contains(.becomesFirstResponderOnAppear) {
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
    
    func endPINInputting(alongside animation: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3) {
            self.pinFieldWrapperView.alpha = 0
            self.pinFieldWrapperHeightConstraint.constant = 0
            self.pinField.resignFirstResponder()
            animation?()
            self.view.layoutIfNeeded()
        }
    }
    
    func reloadTitleView() {
        titleLabel.text = intent.intentTitle
        titleLabel.textColor = if intent.options.contains(.destructiveTitle) {
            R.color.market_red()
        } else {
            R.color.text()
        }
        if let icon = intent.intentTitleIcon {
            if let view = titleImageView {
                view.image = icon
            } else {
                let imageView = UIImageView(image: icon)
                titleStackView.insertArrangedSubview(imageView, at: 0)
                titleStackView.setCustomSpacing(24, after: imageView)
                titleImageView = imageView
            }
        } else {
            titleImageView?.removeFromSuperview()
            titleImageView = nil
        }
        if intent.options.contains(.multipleLineSubtitle) {
            subtitleLabel.numberOfLines = 0
            subtitleLabel.lineBreakMode = .byCharWrapping
        } else {
            subtitleLabel.numberOfLines = 1
            subtitleLabel.lineBreakMode = .byTruncatingTail
        }
        subtitleLabel.text = intent.intentSubtitle
        if let icon = intent.intentSubtitleIconURL {
            let imageView: AvatarImageView
            if let view = subtitleImageView {
                imageView = view
            } else {
                imageView = AvatarImageView()
                imageView.layer.cornerRadius = 8
                imageView.clipsToBounds = true
                imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                subtitleStackView.insertArrangedSubview(imageView, at: 0)
                imageView.snp.makeConstraints { make in
                    make.height.equalTo(imageView.snp.width)
                    make.width.equalTo(16)
                }
                subtitleImageView = imageView
            }
            switch icon {
            case let .app(app):
                imageView.setImage(app: app)
            case let .url(url):
                imageView.imageView.sd_setImage(with: url)
            }
        } else {
            subtitleImageView?.removeFromSuperview()
            subtitleImageView = nil
        }
        UIView.performWithoutAnimation(titleStackView.layoutIfNeeded)
    }
    
    func layoutForAuthenticationFailure(description: String, retryAction: RetryAction) {
        let failureView = R.nib.authenticationFailureView(withOwner: nil)!
        failureView.label.text = description
        switch retryAction {
        case .notAllowed:
            failureView.continueButton.setTitle(R.string.localizable.ok(), for: .normal)
            failureView.continueButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        case .inputPINAgain:
            customTryAgainAction = nil
            failureView.continueButton.setTitle(R.string.localizable.retry(), for: .normal)
            failureView.continueButton.addTarget(self, action: #selector(tryAgain(_:)), for: .touchUpInside)
        case .custom(let action):
            customTryAgainAction = action
            failureView.continueButton.setTitle(R.string.localizable.retry(), for: .normal)
            failureView.continueButton.addTarget(self, action: #selector(tryAgain(_:)), for: .touchUpInside)
        }
        self.view.addSubview(failureView)
        failureView.snp.makeConstraints { make in
            make.top.equalTo(self.pinFieldWrapperView.snp.top)
            make.leading.trailing.equalToSuperview()
        }
        self.failureView = failureView
        self.view.layoutIfNeeded()
        self.validatingIndicator.stopAnimating()
        if let intentViewController = intent as? UIViewController,
           intent.options.contains(.viewUnderPINField)
        {
            intentViewController.view.alpha = 0
        }
        
        UIView.animate(withDuration: 0.3) {
            self.pinField.resignFirstResponder()
            self.pinFieldWrapperHeightConstraint.priority = .almostInexist
            failureView.snp.makeConstraints { make in
                let offset = self.view.safeAreaInsets.bottom > 20 ? 0 : 20
                make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-offset)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func presentationViewControllerWillDismissPresentedViewController(_ notification: Notification) {
        guard let controller = notification.object as? BackgroundDismissablePopupPresentationController else {
            return
        }
        guard controller.presentedViewController == self else {
            return
        }
        intent.authenticationViewControllerWillDismiss(self)
    }
    
    @objc private func enableBiometricAuthentication(_ sender: Any) {
        intent.authenticationViewControllerWillDismiss(self)
        presentingViewController?.dismiss(animated: true) {
            let pinSettings = PinSettingsViewController()
            UIApplication.homeNavigationController?.pushViewController(pinSettings, animated: true)
        }
    }
    
    private func authenticate(with pin: String, onSuccess: (() -> Void)?) {
        closeButton.isHidden = true
        validatingIndicator.startAnimating()
        pinField.isHidden = true
        pinField.receivesInput = false
        authenticateWithBiometryButton?.isHidden = true
        intent.authenticationViewController(self, didInput: pin) { result in
            if !self.intent.options.contains(.unskippable) {
                self.closeButton.isHidden = false
            }
            self.validatingIndicator.stopAnimating()
            switch result {
            case .success:
                onSuccess?()
            case let .failure(error, retryAction):
                if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                    PINVerificationFailureHandler.handle(error: error) { description in
                        self.layoutForAuthenticationFailure(description: description, retryAction: retryAction)
                    }
                } else {
                    self.layoutForAuthenticationFailure(description: error.localizedDescription, retryAction: retryAction)
                }
            }
        }
    }
    
    private func addEnableBiometricAuthButtonIfNeeded() {
        guard !canAuthenticateWithBiometry && !intent.options.contains(.neverRequestAddBiometricAuthentication) else {
            return
        }
        let image: UIImage
        let paymentType: String
        switch BiometryType.payment {
        case .touchID:
            image = R.image.ic_pay_touch()!
            paymentType = R.string.localizable.touch_id()
        case .faceID:
            image = R.image.ic_pay_face()!
            paymentType = R.string.localizable.face_id()
        case .none:
            return
        }
        let button = UIButton(type: .system)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 0)
        button.setImage(image, for: .normal)
        button.setTitle(R.string.localizable.enable_pay_confirmation(paymentType), for: .normal)
        button.addTarget(self, action: #selector(enableBiometricAuthentication(_:)), for: .touchUpInside)
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.width.height.greaterThanOrEqualTo(44)
            make.top.equalTo(pinFieldWrapperView.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.3) {
            self.pinField.resignFirstResponder()
            self.pinFieldWrapperHeightConstraint.priority = .almostInexist
            button.snp.makeConstraints { make in
                let bottomOffset: CGFloat
                if self.view.safeAreaInsets.bottom > 0 {
                    bottomOffset = 0
                } else {
                    bottomOffset = 20
                }
                make.bottom.equalTo(self.keyboardPlaceholderView.snp.top).offset(-bottomOffset)
            }
            self.view.layoutIfNeeded()
        }
    }
    
}

// MARK: - Actions
extension AuthenticationViewController {
    
    @IBAction func close(_ sender: Any) {
        intent.authenticationViewControllerWillDismiss(self)
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func authenticateWithPINField(_ sender: Any) {
        guard pinField.text.count == pinField.numberOfDigits else {
            return
        }
        authenticate(with: pinField.text, onSuccess: {
            AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
            self.addEnableBiometricAuthButtonIfNeeded()
        })
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
                self.authenticate(with: pin, onSuccess: nil)
            }
        }
    }
    
    @objc private func tryAgain(_ sender: Any) {
        func showIntentView() {
            if let intentViewController = intent as? UIViewController,
               intent.options.contains(.viewUnderPINField)
            {
                intentViewController.view.alpha = 1
            }
        }
        
        pinField.clear()
        pinField.isHidden = false
        pinField.receivesInput = true
        authenticateWithBiometryButton?.isHidden = false
        failureView?.removeFromSuperview()
        pinFieldWrapperHeightConstraint.priority = .almostRequired
        if let action = customTryAgainAction {
            showIntentView()
            action()
        } else {
            UIView.animate(withDuration: 0.3) {
                showIntentView()
                self.pinField.becomeFirstResponder()
                self.view.layoutIfNeeded()
            }
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
