import UIKit
import CryptoKit
import MixinServices

final class LoginWithMnemonicViewController: IntroductionViewController, LoginAccountHandler {
    
    enum Action {
        case signIn(MixinMnemonics)
        case signUp
    }
    
    private let action: Action
    private let busyIndicator = ActivityIndicatorView()
    
    private lazy var captcha = Captcha(viewController: self)
    
    private var loginContext: LoginContext?
    
    init(action: Action) {
        self.action = action
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            40
        case .medium:
            80
        case .long, .extraLong:
            120
        }
        contentLabelTopConstraint.constant = 16
        imageView.image = R.image.mnemonic_login()
        switch action {
        case .signIn:
            titleLabel.text = R.string.localizable.signing_in_to_your_account()
        case .signUp:
            titleLabel.text = R.string.localizable.creating_your_account()
        }
        contentTextView.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        contentTextView.adjustsFontForContentSizeCategory = true
        contentTextView.textAlignment = .center
        actionButton.addTarget(self, action: #selector(login(_:)), for: .touchUpInside)
        actionButton.setTitle(R.string.localizable.retry(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        
        busyIndicator.tintColor = R.color.outline_primary()
        actionStackView.addArrangedSubview(busyIndicator)
        busyIndicator.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
        
        login(self)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "login_mnemonic_phrase"])
    }
    
    @objc private func login(_ sender: Any) {
        showLoading()
        if let context = loginContext {
            Logger.login.info(category: "MnemonicLogin", message: "Using saved context")
            login(context: context)
        } else {
            DispatchQueue.global().async { [action, weak self] in
                do {
                    let mnemonics: MixinMnemonics
                    switch action {
                    case .signIn(let m):
                        mnemonics = m
                        Logger.login.info(category: "MnemonicLogin", message: "Using arbitrary mnemonics")
                    case .signUp:
                        mnemonics = try .random()
                        // Save generated random mnemonics
                        AppGroupKeychain.mnemonics = mnemonics.entropy
                        Logger.login.info(category: "MnemonicLogin", message: "New random mnemonics")
                    }
                    let context = try SessionVerificationContext(mnemonics: mnemonics)
                    self?.verifySession(context: context, captchaToken: nil)
                } catch {
                    Logger.login.error(category: "MnemonicLogin", message: "\(error)")
                    DispatchQueue.main.async {
                        self?.showError(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func showLoading() {
        busyIndicator.startAnimating()
        actionButton.isHidden = true
        contentTextView.textColor = R.color.text_tertiary()
        contentTextView.text = R.string.localizable.mnemonic_phrase_take_long()
        contentTextView.isHidden = false
    }
    
    private func showError(_ description: String) {
        busyIndicator.stopAnimating()
        actionButton.isHidden = false
        contentTextView.textColor = R.color.error_red()
        contentTextView.text = description
        contentTextView.isHidden = false
    }
    
}

extension LoginWithMnemonicViewController: Captcha.Reporting {
    
    var reportingContent: (event: Reporter.Event, type: String) {
        switch action {
        case .signUp:
            (event: .signUpCAPTCHA, type: "mnemonic_phrase")
        case .signIn:
            (event: .loginCAPTCHA, type: "mnemonic_phrase")
        }
    }
    
}

extension LoginWithMnemonicViewController {
    
    private enum LoginError: Error {
        case loadVerificationID
    }
    
    private struct LoginContext {
        let masterKey: Ed25519PrivateKey
        let verificationID: String
        let sessionKey = Ed25519PrivateKey()
    }
    
    private func verifySession(context: SessionVerificationContext, captchaToken: CaptchaToken?) {
        Logger.login.info(category: "MnemonicLogin", message: "Verificate")
        AccountAPI.anonymousSessionVerifications(
            publicKey: context.publicKey,
            message: context.message,
            signature: context.signature,
            captchaToken: captchaToken
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let verification):
                let context = LoginContext(
                    masterKey: context.masterKey,
                    verificationID: verification.id
                )
                self.loginContext = context
                if let deactivation = verification.deactivation {
                    let window = DeleteAccountAbortWindow.instance()
                    window.render(deactivation: deactivation) { abort in
                        if abort {
                            self.navigationController?.popToRootViewController(animated: true)
                        } else {
                            self.login(context: context)
                        }
                    }
                    window.presentPopupControllerAnimated()
                } else {
                    self.login(context: context)
                }
            case let .failure(.response(error)) where .requiresCaptcha ~= error:
                Logger.login.info(category: "MnemonicLogin", message: "Captcha")
                self.captcha.validate(errorDescription: error.description) { [weak self] (result) in
                    switch result {
                    case .success(let token):
                        self?.verifySession(context: context, captchaToken: token)
                    case .cancel, .timedOut:
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            case .failure(let error):
                Logger.login.error(category: "MnemonicLogin", message: "\(error)")
                switch action {
                case .signIn:
                    reporter.report(event: .errorSessionVerifications, tags: ["source":"login"])
                case .signUp:
                    reporter.report(event: .errorSessionVerifications, tags: ["source":"sign_up"])
                }
                self.showError(error.localizedDescription)
            }
        }
    }
    
    private func login(context: LoginContext) {
        Logger.login.info(category: "MnemonicLogin", message: "Login")
        do {
            guard let idData = context.verificationID.data(using: .utf8) else {
                throw LoginError.loadVerificationID
            }
            SignalProtocol.shared.initSignal()
            let masterSignature = try context.masterKey.signature(for: idData)
            let registrationID = Int(SignalProtocol.shared.getRegistrationId())
            let sessionSecret = context.sessionKey.publicKey.rawRepresentation
            AccountAPI.login(
                verificationID: context.verificationID,
                masterSignature: masterSignature,
                registrationID: registrationID,
                sessionSecret: sessionSecret
            ) { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case let .success(account):
                    switch self.action {
                    case .signIn(let mnemonics):
                        if account.isAnonymous {
                            AppGroupKeychain.mnemonics = mnemonics.entropy
                            Logger.login.info(category: "MnemonicLogin", message: "Mnemonics saved to Keychain")
                        }
                    case .signUp:
                        break
                    }
                    if let error = self.login(account: account, sessionKey: context.sessionKey) {
                        Logger.login.error(category: "MnemonicLogin", message: "\(error)")
                        self.showError(error.localizedDescription)
                    }
                case let .failure(error):
                    Logger.login.error(category: "MnemonicLogin", message: "\(error)")
                    self.showError(error.localizedDescription)
                }
            }
        } catch {
            Logger.login.error(category: "MnemonicLogin", message: "\(error)")
            self.loginContext = nil
            self.showError(error.localizedDescription)
        }
    }
    
}
