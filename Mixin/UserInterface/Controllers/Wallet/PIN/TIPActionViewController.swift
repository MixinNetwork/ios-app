import UIKit
import MixinServices

final class TIPActionViewController: UIViewController {
    
    enum PIN {
        case legacy(String)
        case tip(String)
    }
    
    enum Action: CustomDebugStringConvertible {
        
        case create(pin: String)
        case change(old: PIN, new: String)
        case migrate(pin: String)
        
        var debugDescription: String {
            switch self {
            case .create:
                return "create"
            case .change:
                return "change"
            case .migrate:
                return "migrate"
            }
        }
        
    }
    
    struct ReportingError: Error, CustomNSError {
        
        let underlying: Error
        let counter: UInt64
        
        var errorUserInfo: [String : Any] {
            ["underlying": "\(underlying)", "counter": counter]
        }
        
    }
    
    private struct ErrorContext {
        let error: Error
        let pin: String
        let accountCounterBefore: UInt64
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    @IBOutlet weak var retryStackView: UIStackView!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    
    @IBOutlet weak var progressStackView: UIStackView!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var progressLabel: UILabel!
    
    private let action: Action
    
    private var errorContext: ErrorContext?
    
    private var tipNavigationController: TIPNavigationController? {
        navigationController as? TIPNavigationController
    }
    
    init(action: Action) {
        self.action = action
        let nib = R.nib.tipActionView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        contentStackView.setCustomSpacing(24, after: iconImageView)
        let descriptionParagraphStyle = NSMutableParagraphStyle()
        descriptionParagraphStyle.lineHeightMultiple = 1.7
        descriptionParagraphStyle.alignment = .center
        descriptionLabel.attributedText = NSAttributedString(
            string: R.string.localizable.syncing_and_verifying_tip(),
            attributes: [
                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .foregroundColor: R.color.text_tertiary()!,
                .paragraphStyle: descriptionParagraphStyle,
            ]
        )
        retryButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = .white
            return AttributedString(
                R.string.localizable.retry(),
                attributes: attributes
            )
        }()
        progressLabel.font = UIFontMetrics.default.scaledFont(
            for: .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        )
        progressLabel.adjustsFontForContentSizeCategory = true
        
        guard let accountCounterBefore = LoginManager.shared.account?.tipCounter else {
            return
        }
        switch action {
        case let .create(pin):
            titleLabel.text = R.string.localizable.set_up_pin()
#if DEBUG
            if TIPDiagnostic.uiTestOnly {
                emulateProgress()
                return
            }
#endif
            Task {
                do {
                    let (_, account) = try await TIP.createTIPPriv(
                        pin: pin,
                        failedSigners: [],
                        legacyPIN: nil,
                        forRecover: false,
                        progressHandler: showProgress
                    )
                    AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                    try await TIP.registerToSafeIfNeeded(account: account, pin: pin)
                    try await TIP.registerDefaultCommonWalletIfNeeded(pin: pin)
                    AppGroupUserDefaults.User.loginPINValidated = true
                    await MainActor.run {
                        reporter.report(event: .signUpEnd)
                        finish()
                    }
                } catch {
                    await handle(
                        error: error,
                        pin: pin,
                        accountCounterBefore: accountCounterBefore
                    )
                }
            }
        case let .change(old, new):
            titleLabel.text = R.string.localizable.change_pin()
#if DEBUG
            if TIPDiagnostic.uiTestOnly {
                emulateProgress()
                return
            }
#endif
            Task {
                do {
                    let account = switch old {
                    case let .legacy(old):
                        try await TIP.createTIPPriv(
                            pin: new,
                            failedSigners: [],
                            legacyPIN: old,
                            forRecover: false,
                            progressHandler: showProgress
                        ).account
                    case let .tip(old):
                        try await TIP.updateTIPPriv(
                            oldPIN: old,
                            newPIN: new,
                            isCounterBalanced: true,
                            failedSigners: [],
                            progressHandler: showProgress
                        )
                    }
                    if AppGroupUserDefaults.Wallet.payWithBiometricAuthentication {
                        Keychain.shared.storePIN(pin: new)
                    }
                    AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                    AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                    try await TIP.registerToSafeIfNeeded(account: account, pin: new)
                    try await TIP.registerDefaultCommonWalletIfNeeded(pin: new)
                    AppGroupUserDefaults.User.loginPINValidated = true
                    await MainActor.run {
                        finish()
                    }
                } catch {
                    await handle(
                        error: error,
                        pin: new,
                        accountCounterBefore: accountCounterBefore
                    )
                }
            }
        case let .migrate(pin):
            titleLabel.text = R.string.localizable.upgrade_tip()
#if DEBUG
            if TIPDiagnostic.uiTestOnly {
                emulateProgress()
                return
            }
#endif
            Task {
                do {
                    let (_, account) = try await TIP.createTIPPriv(
                        pin: pin,
                        failedSigners: [],
                        legacyPIN: pin,
                        forRecover: false,
                        progressHandler: showProgress
                    )
                    AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                    try await TIP.registerToSafeIfNeeded(account: account, pin: pin)
                    try await TIP.registerDefaultCommonWalletIfNeeded(pin: pin)
                    AppGroupUserDefaults.User.loginPINValidated = true
                    await MainActor.run {
                        finish()
                    }
                } catch {
                    await handle(
                        error: error,
                        pin: pin,
                        accountCounterBefore: accountCounterBefore
                    )
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Logger.tip.info(category: "TIPAction", message: "View did appear with action: \(action.debugDescription)")
    }
    
    @IBAction func tryAgain(_ sender: Any) {
        guard let context = errorContext else {
            return
        }
        Task {
            await handle(context: context)
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "tip_action"])
    }
    
    @MainActor
    private func finish() {
        Logger.tip.info(category: "TIPAction", message: "Finished successfully")
        switch action {
        case .create:
            tipNavigationController?.finish()
        case .change:
            alert(R.string.localizable.change_pin_successfully()) { (_) in
                self.tipNavigationController?.finish()
            }
        case .migrate:
            alert(R.string.localizable.upgrade_tip_successfully()) { (_) in
                self.tipNavigationController?.finish()
            }
        }
    }
    
    private func handle(
        error: Error,
        pin: String,
        accountCounterBefore: UInt64,
    ) async {
        let reportingError = ReportingError(underlying: error, counter: accountCounterBefore)
        reporter.report(error: reportingError)
        Logger.tip.error(category: "TIPAction", message: "Failed with: \(error)")
        let context = ErrorContext(
            error: error,
            pin: pin,
            accountCounterBefore: accountCounterBefore
        )
        self.errorContext = context
        await handle(context: context)
    }
    
    private func handle(context: ErrorContext) async {
        await MainActor.run {
            showProgress(.connecting)
        }
        do {
            if let context = try await TIP.checkCounter() {
                await MainActor.run {
                    let intro = TIPIntroViewController(context: context)
                    navigationController?.setViewControllers([intro], animated: true)
                }
            } else {
                guard let accountCounterAfter = LoginManager.shared.account?.tipCounter else {
                    throw TIP.Error.noAccount
                }
                if accountCounterAfter == context.accountCounterBefore {
                    Logger.tip.error(category: "TIPAction", message: "Nothing changed")
                    await MainActor.run {
                        let intro = TIPIntroViewController(
                            action: action,
                            changedNothingWith: context.error
                        )
                        navigationController?.setViewControllers([intro], animated: true)
                    }
                } else {
                    Logger.tip.warn(category: "TIPAction", message: "No interruption is detected")
                    try await TIP.registerToSafeIfNeeded(account: nil, pin: context.pin)
                    try await TIP.registerDefaultCommonWalletIfNeeded(pin: context.pin)
                    AppGroupUserDefaults.User.loginPINValidated = true
                    Logger.tip.warn(category: "TIPAction", message: "Registration finished")
                    await MainActor.run {
                        finish()
                    }
                }
            }
        } catch {
            Logger.tip.error(category: "TIPAction", message: "Handle failed with: \(error)")
            retryStackView.isHidden = false
            progressStackView.isHidden = true
            errorDescriptionLabel.text = error.localizedDescription
        }
    }
    
    private func showProgress(_ progress: TIP.Progress) {
        retryStackView.isHidden = true
        progressStackView.isHidden = false
        activityIndicatorView.startAnimating()
        switch progress {
        case .creating:
            progressLabel.text = R.string.localizable.generating_keys()
        case .connecting:
            progressLabel.text = R.string.localizable.trying_connect_tip_node()
        case .synchronizing(let fractionCompleted):
            let percent = Int(ceil(fractionCompleted * 100))
            progressLabel.text = R.string.localizable.exchanging_data("\(percent)")
        }
    }
    
#if DEBUG
    private func emulateProgress() {
        DispatchQueue.main.async {
            self.showProgress(.creating)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showProgress(.connecting)
        }
        for i in 0...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(i + 4)) {
                let fractionComplete = Float(i + 1) / 7
                if !TIPDiagnostic.failLastSignerOnce || i < 6 {
                    self.showProgress(.synchronizing(fractionComplete))
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 13) {
            if TIPDiagnostic.failLastSignerOnce || TIPDiagnostic.failPINUpdateServerSideOnce {
                let action: TIP.Action
                switch self.action {
                case .create:
                    action = .create
                case .change:
                    action = .change
                case .migrate:
                    action = .migrate
                }
                
                let situation: TIP.InterruptionContext.Situation
                if TIPDiagnostic.failLastSignerOnce {
                    TIPDiagnostic.failLastSignerOnce = false
                    situation = .pendingSign([])
//                } else if TIPDiagnostic.failPINUpdateServerSideOnce {
//                    TIPDiagnostic.failPINUpdateServerSideOnce = false
//                    situation = .pendingUpdate
                } else {
                    fatalError()
                }
                
                let context = TIP.InterruptionContext(action: action, situation: situation, accountTIPCounter: 2, maxNodeCounter: 2)
                let intro = TIPIntroViewController(context: context)
                self.navigationController?.setViewControllers([intro], animated: true)
            } else {
                self.finish()
            }
        }
    }
#endif
    
}
