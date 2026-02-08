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
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var activityIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var progressLabel: UILabel!
    
    private let action: Action
    
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
        progressLabel.font = UIFontMetrics.default.scaledFont(for: .monospacedDigitSystemFont(ofSize: 14, weight: .regular))
        progressLabel.adjustsFontForContentSizeCategory = true
        performAction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Logger.tip.info(category: "TIPAction", message: "View did appear with action: \(action.debugDescription)")
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "tip_action"])
    }
    
    private func performAction() {
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
                    await handle(error: error, accountCounterBefore: accountCounterBefore)
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
                    await handle(error: error, accountCounterBefore: accountCounterBefore)
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
                    await handle(error: error, accountCounterBefore: accountCounterBefore)
                }
            }
        }
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
    
    private func handle(error: Error, accountCounterBefore: UInt64) async {
        let reportingError = ReportingError(underlying: error, counter: accountCounterBefore)
        reporter.report(error: reportingError)
        Logger.tip.error(category: "TIPAction", message: "Failed with: \(error)")
        do {
            if let context = try await TIP.checkCounter() {
                await MainActor.run {
                    let intro = TIPIntroViewController(context: context)
                    navigationController?.setViewControllers([intro], animated: true)
                }
            } else {
                try await MainActor.run {
                    guard let accountCounterAfter = LoginManager.shared.account?.tipCounter else {
                        throw TIP.Error.noAccount
                    }
                    if accountCounterAfter == accountCounterBefore {
                        Logger.tip.error(category: "TIPAction", message: "Nothing changed")
                        let intro = TIPIntroViewController(action: action, changedNothingWith: error)
                        navigationController?.setViewControllers([intro], animated: true)
                    } else {
                        Logger.tip.warn(category: "TIPAction", message: "No interruption is detected")
                        finish()
                    }
                }
            }
        } catch {
            Logger.tip.error(category: "TIPAction", message: "Handle failed with: \(error)")
            await MainActor.run {
                let intro: TIPIntroViewController
                switch action {
                case .create:
                    intro = TIPIntroViewController(intent: .create)
                case .change:
                    intro = TIPIntroViewController(intent: .change)
                case .migrate:
                    intro = TIPIntroViewController(intent: .migrate)
                }
                navigationController?.setViewControllers([intro], animated: true)
            }
        }
    }
    
    private func showProgress(_ progress: TIP.Progress) {
        switch progress {
        case .creating:
            activityIndicatorView.startAnimating()
            progressView.isHidden = true
            progressLabel.text = R.string.localizable.generating_keys()
        case .connecting:
            activityIndicatorView.startAnimating()
            progressView.isHidden = true
            progressLabel.text = R.string.localizable.trying_connect_tip_node()
        case .synchronizing(let fractionCompleted):
            activityIndicatorView.stopAnimating()
            progressView.isHidden = false
            progressView.progress = fractionCompleted
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
