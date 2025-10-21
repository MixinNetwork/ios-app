import UIKit
import MixinServices

final class SignInWithMobileNumberViewController: SignUpWithMobileNumberViewController {
    
    override var intent: PhoneNumberVerificationContext.Intent {
        .signIn
    }
    
    override var reportingContent: (event: Reporter.Event, type: String) {
        (event: .loginCAPTCHA, type: "phone_number")
    }
    
    private let separatorLineView = R.nib.loginSeparatorLineView(withOwner: nil)!
    private let mnemonicLoginButton = StyledButton(type: .system)
    private let signupButton = StyledButton(type: .system)
    
    private var isBusy = false
    
    override func setupView() {
        navigationItem.rightBarButtonItems = [
            .customerService(target: self, action: #selector(presentCustomerService(_:))),
        ]
        
        declarationTextView.attributedText = .agreement()
        
        actionStackView.addArrangedSubview(separatorLineView)
        separatorLineView.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        
        mnemonicLoginButton.setTitle(R.string.localizable.sign_in_with_mnemonic_phrase(), for: .normal)
        mnemonicLoginButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        mnemonicLoginButton.style = .outline
        mnemonicLoginButton.applyDefaultContentInsets()
        actionStackView.addArrangedSubview(mnemonicLoginButton)
        mnemonicLoginButton.addTarget(self, action: #selector(mnemonicLogin(_:)), for: .touchUpInside)
        
        signupButton.setTitle(R.string.localizable.sign_in_no_account(), for: .normal)
        signupButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        signupButton.style = .tinted
        contentView.addSubview(signupButton)
        signupButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.trailing.equalToSuperview().offset(-36)
            make.bottom.equalTo(contentView.snp.bottom).offset(-30)
        }
        signupButton.applyDefaultContentInsets()
        signupButton.addTarget(self, action: #selector(signup(_:)), for: .touchUpInside)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func updateViews(isBusy: Bool) {
        self.isBusy = isBusy
        super.updateViews(isBusy: isBusy)
        isBusy ? hideOtherOptions() : showOtherOptions()
    }
    
    @objc private func mnemonicLogin(_ sender: Any) {
        let signIn = SignInWithMnemonicsViewController()
        navigationController?.pushViewController(signIn, animated: true)
    }
    
    @objc private func signup(_ sender: Any) {
        guard let navigationController else {
            return
        }
        var viewControllers = navigationController.viewControllers
        viewControllers.removeAll { viewController in
            !(viewController is OnboardingViewController)
        }
        viewControllers.append(SignUpViewController())
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        hideOtherOptions()
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        if !isBusy && presentedViewController == nil {
            showOtherOptions()
        }
    }
    
    private func hideOtherOptions() {
        separatorLineView.alpha = 0
        mnemonicLoginButton.alpha = 0
        signupButton.alpha = 0
    }
    
    private func showOtherOptions() {
        separatorLineView.alpha = 1
        mnemonicLoginButton.alpha = 1
        signupButton.alpha = 1
    }
    
}
