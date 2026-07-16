import UIKit
import MixinServices

protocol CheckSessionEnvironmentChild {
    
}

extension CheckSessionEnvironmentChild where Self: UIViewController {
    
    var sessionEnvironmentChecker: CheckSessionEnvironmentViewController? {
        parent as? CheckSessionEnvironmentViewController
        ?? navigationController?.parent as? CheckSessionEnvironmentViewController
    }
    
    var isCheckingSessionEnvironment: Bool {
        sessionEnvironmentChecker != nil
    }
    
    func checkSessionEnvironmentAgain(
        freshAccount: Account? = nil,
        importWalletEncryptionKey: Data? = nil,
        custodialSalt: Data? = nil,
    ) {
        if let checker = sessionEnvironmentChecker {
            checker.check(
                freshAccount: freshAccount,
                importWalletEncryptionKey: importWalletEncryptionKey,
                custodialSalt: custodialSalt,
            )
        } else {
            assertionFailure()
        }
    }
    
}

final class CheckSessionEnvironmentViewController: LoginLoadingViewController {
    
    private(set) weak var contentViewController: UIViewController?
    
    private lazy var restoreChatNavigationHandler = RestoreChatNavigationHandler()
    private lazy var navigationBarAppearanceUpdater = NavigationBarStyle.AppearanceUpdater()
    
    private weak var retryButton: UIButton?
    
    private var account: Account
    private var isAccountFresh: Bool
    private var importWalletEncryptionKey: Data?
    private var custodialSalt: Data?
    
    private var initialBots: [String] {
        if Locale.preferredLanguages.first?.hasPrefix("zh-Hans") ?? false {
            [
                BotUserID.teamMixin,
                BotUserID.mixinRoute,
                BotUserID.marketAlerts,
                BotUserID.mixinDiscourse,
                BotUserID.rewards,
                BotUserID.mixinCard,
                BotUserID.mixinCash,
                BotUserID.mixinChineseGroup,
            ]
        } else {
            [
                BotUserID.teamMixin,
                BotUserID.mixinRoute,
                BotUserID.marketAlerts,
                BotUserID.mixinCommunity,
                BotUserID.rewards,
                BotUserID.mixinCard,
                BotUserID.mixinCash,
                BotUserID.mixinGlobalGroup,
            ]
        }
    }
    
    init(freshAccount account: Account) {
        self.account = account
        self.isAccountFresh = true
        super.init()
    }
    
    init(localAccount account: Account) {
        self.account = account
        self.isAccountFresh = false
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        Logger.login.info(category: "CheckSessionEnvironment", message: "View loaded with account fresh: \(isAccountFresh), intent: \(AccountVerificationIntent.current?.debugDescription ?? "(null)")")
        if AccountVerificationIntent.current == nil {
            // Permissive path for app relauncch
            check()
        } else {
            // Strict path for login
            if isAccountFresh {
                check()
            } else {
                reloadAccountThenCheck()
            }
        }
    }
    
    func check(
        freshAccount: Account? = nil,
        importWalletEncryptionKey: Data? = nil,
        custodialSalt: Data? = nil,
    ) {
        assert(Thread.isMainThread)
        if let freshAccount {
            Logger.login.info(category: "CheckSessionEnvironment", message: "Account refreshed")
            self.account = freshAccount
            self.isAccountFresh = true
        }
        if let importWalletEncryptionKey {
            self.importWalletEncryptionKey = importWalletEncryptionKey
        }
        if let custodialSalt {
            self.custodialSalt = custodialSalt
        }
        
        // `self.account` is guaranteed to be fresh afterwards, unless it's not necessary
        //
        // It either comes from the argument of `freshAccount`, or it's a property of this class.
        // In the latter case, `viewDidLoad` verifies or fetch to make it fresh, but only when
        // it's in login progress. When it's simple app relaunch, the checking is permissive.
        //
        // For checking items that causes an account update, `check(freshAccount:)` should be
        // manually executed by the child, after it finishes its job
        
        Logger.login.info(category: "CheckSessionEnvironment", message: "Check environments")
        if AppGroupUserDefaults.isClockSkewed {
            Logger.login.info(category: "CheckSessionEnvironment", message: "Clock skewed")
            while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
            }
            let clockSkew = ClockSkewViewController()
            reload(content: clockSkew)
        } else if account.hasEmptyName {
            Logger.login.info(category: "CheckSessionEnvironment", message: "Create username")
            let username = UsernameViewController()
            let navigationController = GeneralAppearanceNavigationController(rootViewController: username)
            reload(content: navigationController)
        } else if AppGroupUserDefaults.Account.canRestoreFromPhone {
            Logger.login.info(category: "CheckSessionEnvironment", message: "Restore chat")
            let restore = RestoreChatViewController()
            let navigationController = GeneralAppearanceNavigationController(rootViewController: restore)
            navigationController.delegate = restoreChatNavigationHandler
            reload(content: navigationController)
        } else if DatabaseUpgradeViewController.needsUpgrade {
            Logger.login.info(category: "CheckSessionEnvironment", message: "Upgrade db")
            let upgrade = DatabaseUpgradeViewController()
            reload(content: upgrade)
        } else if !SignalLoadingViewController.isLoaded {
            Logger.login.info(category: "CheckSessionEnvironment", message: "Load Signal")
            let signalLoading = SignalLoadingViewController()
            let navigationController = SecondaryAppearanceNavigationController(rootViewController: signalLoading)
            reload(content: navigationController)
        } else if !account.hasPIN {
            Logger.login.info(category: "CheckSessionEnvironment", message: "Create PIN for account: \(account.userID)")
            // No need to detect interruption, the TIP view will do it
            let navigationController = TIPNavigationController(intent: .create)
            reload(content: navigationController)
        } else {
            let isReady = account.hasSafe
                && AppGroupUserDefaults.User.loginPINValidated
                && Web3WalletDAO.shared.hasClassicWallet()
            guard isReady else {
                registerNecessaries()
                return
            }
            switch AccountVerificationIntent.current {
            case .none:
                Logger.login.info(category: "CheckSessionEnvironment", message: "App relaunch checking finished")
                finishChecking(initialTab: .chat)
            case .signUp(.mixinMnemonics), .signUp(.mobileNumber):
                Logger.login.info(category: "CheckSessionEnvironment", message: "Sign up checking finished")
                finishChecking(initialTab: .wallet)
            case .signIn(.mixinMnemonics), .signIn(.mobileNumber):
                Logger.login.info(category: "CheckSessionEnvironment", message: "Sign in checking finished")
                finishChecking(initialTab: .wallet)
            case .signIn(.bip39Mnemonics), .signUp(.bip39Mnemonics):
                Logger.login.error(category: "CheckSessionEnvironment", message: "Import BIP-39 Wallet")
                guard let importWalletKey = self.importWalletEncryptionKey else {
                    // The key should be ready after the registration
                    Logger.login.warn(category: "CheckSessionEnvironment", message: "Missing import wallet key")
                    registerNecessaries()
                    return
                }
                do {
                    let entropy: Data
                    if let mnemonics = AppGroupKeychain.mnemonics {
                        entropy = mnemonics
                    } else if let salt = self.custodialSalt {
                        // For 12/24 Mnemonics users with phone number added
                        // They have `AppGroupKeychain.mnemonics` deleted by receiving account
                        // Use custodialSalt instead
                        entropy = salt
                    } else {
                        Logger.login.error(category: "CheckSessionEnvironment", message: "Missing entropy")
                        throw RegisterError.missingEntropy
                    }
                    let mnemonics = try BIP39Mnemonics(entropy: entropy)
                    let encryptedMnemonics = try EncryptedBIP39Mnemonics(
                        mnemonics: mnemonics,
                        key: importWalletKey
                    )
                    let fetch = AddWalletFetchAddressViewController(
                        mnemonics: mnemonics,
                        encryptedMnemonics: encryptedMnemonics,
                        behavior: .breaksOnImportedWalletFound({ [weak self] walletID in
                            self?.finishCheckingForBIP39Session(
                                welcomeWalletID: walletID,
                                updateWalletSecretsWith: encryptedMnemonics,
                            )
                        })
                    )
                    let navigation = GeneralAppearanceNavigationController(rootViewController: fetch)
                    navigation.delegate = navigationBarAppearanceUpdater
                    reload(content: navigation)
                } catch {
                    Logger.login.error(category: "CheckSessionEnvironment", message: "Invalid entropy: \(error)")
                    // No way to recover from bad entropy. Go back to start around.
                    AppDelegate.current.mainWindow.rootViewController = LoginNavigationController()
                }
            }
        }
    }
    
    func finishCheckingForBIP39Session(
        welcomeWalletID: String?,
        updateWalletSecretsWith mnemonics: EncryptedBIP39Mnemonics? = nil, // nil for not updating
    ) {
        Logger.login.info(category: "CheckSessionEnvironment", message: "BIP39 checking finished")
        if let mnemonics {
            let wallets = Web3WalletDAO.shared.wallets()
            for wallet in wallets {
                switch wallet.category.knownCase {
                case .importedMnemonic:
                    Logger.login.info(category: "CheckSessionEnvironment", message: "Saved mnemonics for wallet: \(wallet.walletID)")
                    AppGroupKeychain.setImportedMnemonics(mnemonics, forWalletID: wallet.walletID)
                case .importedPrivateKey:
                    break
                case .classic, .watchAddress, .none:
                    break
                }
            }
        }
        if let id = welcomeWalletID {
            AppGroupUserDefaults.Wallet.lastSelectedWallet = .common(id: id)
        }
        finishChecking(initialTab: .wallet)
    }
    
    @objc private func reloadAccountThenCheck() {
        removeContentViewController()
        activityIndicator.startAnimating()
        descriptionLabel.text = R.string.localizable.initializing()
        descriptionLabel.textColor = R.color.text_tertiary()
        retryButton?.removeFromSuperview()
        AccountAPI.me { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let account):
                self.check(freshAccount: account)
            case .failure(let error):
                self.reportFailure(
                    description: error.localizedDescription,
                    retryWithSelector: #selector(reloadAccountThenCheck)
                )
            }
        }
    }
    
    @objc private func registerNecessaries() {
        Logger.login.info(category: "CheckSessionEnvironment", message: "Register necessaries for account: \(account.userID)")
        removeContentViewController()
        activityIndicator.startAnimating()
        descriptionLabel.text = R.string.localizable.initializing()
        descriptionLabel.textColor = R.color.text_tertiary()
        Task {
            do {
                let context = try await TIP.checkCounter(with: account)
                await MainActor.run {
                    if let context {
                        let intro = TIPIntroViewController(context: context)
                        let navigation = TIPNavigationController(intro: intro)
                        reload(content: navigation)
                        switch context.action {
                        case .create:
                            break
                        case .change:
                            reporter.report(event: .loginPINVerify, tags: ["type": "pin_change"])
                        case .migrate:
                            reporter.report(event: .loginPINVerify, tags: ["type": "pin_upgrade"])
                        }
                    } else {
                        let validation = LoginPINValidationViewController(account: account)
                        let navigation = GeneralAppearanceNavigationController(rootViewController: validation)
                        reload(content: navigation)
                    }
                }
            } catch {
                Logger.login.error(category: "LoginPINStatusChecking", message: "Failed: \(error)")
                await MainActor.run {
                    reportFailure(
                        description: error.localizedDescription,
                        retryWithSelector: #selector(registerNecessaries)
                    )
                }
            }
        }
    }
    
    private func removeContentViewController() {
        if let content = contentViewController {
            content.willMove(toParent: nil)
            content.view.removeFromSuperview()
            content.removeFromParent()
        }
    }
    
    private func reload(content: UIViewController) {
        removeContentViewController()
        addChild(content)
        view.addSubview(content.view)
        content.view.snp.makeEdgesEqualToSuperview()
        content.didMove(toParent: self)
        self.contentViewController = content
    }
    
    private func finishChecking(initialTab: HomeTabBarController.ChildID) {
        Logger.redirectLogsToLogin = false
        
        let intent = AccountVerificationIntent.current
        switch intent {
        case .signUp:
            reporter.report(event: .signUpEnd)
        case .signIn:
            reporter.report(event: .loginEnd)
            Logger.login.info(category: "CheckSessionEnvironment", message: "Sync contacts")
            ContactAPI.syncContacts()
        case nil:
            break
        }
        AccountVerificationIntent.current = nil
        
        AppDelegate.current.mainWindow.rootViewController = HomeContainerViewController(initialTab: initialTab)
        
        if intent != nil {
            assert(MixinKeys.testAccountPrefix != nil)
            let initializeBots: Bool
            if let phone = account.phone, let invalidPrefix = MixinKeys.testAccountPrefix {
                initializeBots = !phone.hasPrefix(invalidPrefix)
            } else {
                initializeBots = true
            }
            if initializeBots {
                Logger.login.info(category: "CheckSessionEnvironment", message: "Initialize bots")
                for id in initialBots {
                    let job = InitializeBotJob(userID: id)
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            }
        }
    }
    
    private func reportFailure(
        description: String,
        retryWithSelector retrySelector: Selector
    ) {
        activityIndicator.stopAnimating()
        descriptionLabel.text = description
        descriptionLabel.textColor = R.color.error_red()
        var retryConfig: UIButton.Configuration = .filled()
        retryConfig.baseBackgroundColor = R.color.theme()
        retryConfig.baseForegroundColor = .white
        retryConfig.attributedTitle = AttributedString(
            string: R.string.localizable.retry(),
            scalingByFontSize: 16,
            weight: .medium
        )
        retryConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 36, bottom: 15, trailing: 36)
        let button = UIButton(configuration: retryConfig)
        button.addTarget(self, action: retrySelector, for: .touchUpInside)
        bottomStackView.addArrangedSubview(button)
        self.retryButton = button
    }
    
}

extension CheckSessionEnvironmentViewController {
    
    private enum RegisterError: Error {
        case missingEntropy
    }
    
    private final class RestoreChatNavigationHandler: NSObject, UINavigationControllerDelegate {
        
        private lazy var presentFromBottomAnimator = PresentFromBottomAnimator()
        
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            if viewController is QRCodeScannerViewController && !navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(true, animated: animated)
            } else if !(viewController is QRCodeScannerViewController) && navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: animated)
            }
        }
        
        func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            if operation == .push {
                if let targetVC = toVC as? MixinNavigationAnimating {
                    switch targetVC.pushAnimation {
                    case .push:
                        return nil
                    case .present:
                        presentFromBottomAnimator.operation = operation
                        return presentFromBottomAnimator
                    }
                }
            } else if operation == .pop {
                if let targetVC = fromVC as? MixinNavigationAnimating {
                    switch targetVC.popAnimation {
                    case .pop:
                        return nil
                    case .dismiss:
                        presentFromBottomAnimator.operation = operation
                        return presentFromBottomAnimator
                    }
                }
            }
            return nil
        }
        
    }
    
    private final class FetchWalletNavigationController: GeneralAppearanceNavigationController {
        
        private lazy var presentFromBottomAnimator = PresentFromBottomAnimator()
        
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            if viewController is QRCodeScannerViewController && !navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(true, animated: animated)
            } else if !(viewController is QRCodeScannerViewController) && navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: animated)
            }
        }
        
        func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            if operation == .push {
                if let targetVC = toVC as? MixinNavigationAnimating {
                    switch targetVC.pushAnimation {
                    case .push:
                        return nil
                    case .present:
                        presentFromBottomAnimator.operation = operation
                        return presentFromBottomAnimator
                    }
                }
            } else if operation == .pop {
                if let targetVC = fromVC as? MixinNavigationAnimating {
                    switch targetVC.popAnimation {
                    case .pop:
                        return nil
                    case .dismiss:
                        presentFromBottomAnimator.operation = operation
                        return presentFromBottomAnimator
                    }
                }
            }
            return nil
        }
        
    }
    
}
