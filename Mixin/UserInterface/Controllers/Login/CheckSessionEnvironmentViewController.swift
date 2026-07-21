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
        pin: String? = nil,
    ) {
        if let checker = sessionEnvironmentChecker {
            checker.check(
                freshAccount: freshAccount,
                freshPIN: pin,
            )
        } else {
            assertionFailure()
        }
    }
    
}

final class CheckSessionEnvironmentViewController: LoginLoadingViewController {
    
    typealias BIP39MnemonicsGroup = (plain: BIP39Mnemonics, encrypted: EncryptedBIP39Mnemonics)
    
    private(set) weak var contentViewController: UIViewController?
    
    private lazy var restoreChatNavigationHandler = RestoreChatNavigationHandler()
    private lazy var navigationBarAppearanceUpdater = NavigationBarStyle.AppearanceUpdater()
    
    private weak var retryButton: UIButton?
    
    private var account: Account
    private var isAccountFresh: Bool
    private var pin: String?
    
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
    
    deinit {
        Logger.login.debug(category: "CheckSessionEnv", message: "Deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.login.info(category: "CheckSessionEnv", message: "View loaded with account fresh: \(isAccountFresh), intent: \(AccountVerificationIntent.current?.debugDescription ?? "(null)")")
        
        view.backgroundColor = R.color.background_secondary()
        
        let navigationBar = UINavigationBar()
        navigationBar.standardAppearance = .secondaryBackgroundColor
        navigationBar.scrollEdgeAppearance = .secondaryBackgroundColor
        topStackView.addArrangedSubview(navigationBar)
        let navigationItem = UINavigationItem()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        navigationBar.setItems([navigationItem], animated: false)
        
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
        freshPIN: String? = nil,
    ) {
        assert(Thread.isMainThread)
        if let freshAccount {
            Logger.login.info(category: "CheckSessionEnv", message: "Account refreshed, has_pin: \(freshAccount.hasPIN), has_safe: \(freshAccount.hasSafe)")
            self.account = freshAccount
            self.isAccountFresh = true
        }
        if let freshPIN {
            self.pin = freshPIN
        }
        
        // `self.account` is guaranteed to be fresh afterwards, unless it's not necessary
        //
        // It either comes from the argument of `freshAccount`, or it's a property of this class.
        // In the latter case, `viewDidLoad` verifies or fetch to make it fresh, but only when
        // it's in login progress. When it's simple app relaunch, the checking is permissive.
        //
        // For checking items that causes an account update, `check(freshAccount:)` should be
        // manually executed by the child, after it finishes its job
        
        Logger.login.info(category: "CheckSessionEnv", message: "Check environments")
        if AppGroupUserDefaults.isClockSkewed {
            Logger.login.info(category: "CheckSessionEnv", message: "Clock skewed")
            while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
            }
            let clockSkew = ClockSkewViewController()
            reload(content: clockSkew)
        } else if account.hasEmptyName {
            Logger.login.info(category: "CheckSessionEnv", message: "Create username")
            let username = UsernameViewController()
            let navigationController = SecondaryAppearanceNavigationController(rootViewController: username)
            reload(content: navigationController)
        } else if AppGroupUserDefaults.Account.canRestoreFromPhone {
            Logger.login.info(category: "CheckSessionEnv", message: "Restore chat")
            let restore = RestoreChatViewController()
            let navigationController = GeneralAppearanceNavigationController(rootViewController: restore)
            navigationController.delegate = restoreChatNavigationHandler
            reload(content: navigationController)
        } else if DatabaseUpgradeViewController.needsUpgrade {
            Logger.login.info(category: "CheckSessionEnv", message: "Upgrade db")
            let upgrade = DatabaseUpgradeViewController()
            reload(content: upgrade)
        } else if !SignalLoadingViewController.isLoaded {
            Logger.login.info(category: "CheckSessionEnv", message: "Load Signal")
            let signalLoading = SignalLoadingViewController()
            let navigationController = SecondaryAppearanceNavigationController(rootViewController: signalLoading)
            reload(content: navigationController)
        } else if !account.hasPIN {
            Logger.login.info(category: "CheckSessionEnv", message: "Create PIN for account: \(account.userID)")
            // No need to detect interruption, the TIP view will do it
            let navigationController = TIPNavigationController(intent: .create)
            reload(content: navigationController)
        } else if !AppGroupUserDefaults.User.loginPINValidated {
            validatePIN()
        } else if !account.hasSafe || !Web3WalletDAO.shared.hasClassicWallet() {
            registerNecessaries()
        } else {
            switch AccountVerificationIntent.current {
            case .none:
                Logger.login.info(category: "CheckSessionEnv", message: "App relaunch checking finished")
                finishChecking(initialTab: .chat)
            case .signUp(.mixinMnemonics), .signUp(.mobileNumber):
                Logger.login.info(category: "CheckSessionEnv", message: "Sign up checking finished")
                finishChecking(initialTab: .wallet)
            case .signIn(.mixinMnemonics), .signIn(.mobileNumber):
                Logger.login.info(category: "CheckSessionEnv", message: "Sign in checking finished")
                finishChecking(initialTab: .wallet)
            case .signIn(.bip39Mnemonics), .signUp(.bip39Mnemonics):
                if account.hasSaltExported {
                    importBIP39Wallets()
                } else {
                    markMnemonicsExported()
                }
            }
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "check_session_env"])
    }
    
    @objc private func reloadAccountThenCheck() {
        reportBusy()
        Logger.login.info(category: "CheckSessionEnv", message: "Reload account from remote then check")
        AccountAPI.me { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                self.check(freshAccount: account)
            case .failure(let error):
                Logger.login.error(category: "CheckSessionEnv", message: "Unable to reload account: \(error)")
                self.reportFailure(
                    description: error.localizedDescription,
                    retryWithSelector: #selector(reloadAccountThenCheck)
                )
            }
        }
    }
    
    @objc private func validatePIN() {
        Logger.login.info(category: "CheckSessionEnv", message: "Validate PIN for account: \(account.userID)")
        reportBusy()
        Task {
            do {
                let context = try await TIP.checkCounter(with: account)
                await MainActor.run {
                    if let context {
                        Logger.login.info(category: "CheckSessionEnv", message: "Interruption detected")
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
                        Logger.login.info(category: "CheckSessionEnv", message: "No interruption, start validation")
                        let validation = LoginPINValidationViewController(account: account)
                        let navigation = GeneralAppearanceNavigationController(rootViewController: validation)
                        reload(content: navigation)
                    }
                }
            } catch {
                Logger.login.error(category: "CheckSessionEnv", message: "Validation failed: \(error)")
                await MainActor.run {
                    reportFailure(
                        description: error.localizedDescription,
                        retryWithSelector: #selector(validatePIN)
                    )
                }
            }
        }
    }
    
    private func finishChecking(initialTab: HomeTabBarController.ChildID) {
        Logger.redirectLogsToLogin = false
        
        let intent = AccountVerificationIntent.current
        switch intent {
        case .signUp:
            reporter.report(event: .signUpEnd)
        case .signIn:
            reporter.report(event: .loginEnd)
            Logger.login.info(category: "CheckSessionEnv", message: "Sync contacts")
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
                Logger.login.info(category: "CheckSessionEnv", message: "Initialize bots")
                for id in initialBots {
                    let job = InitializeBotJob(userID: id)
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            }
        }
    }
    
}

// MARK: - Necessaries Registration
// Safe, Default common wallet
extension CheckSessionEnvironmentViewController {
    
    @objc private func reloadAccountThenRegisterNecessaries() {
        reportBusy()
        Logger.login.info(category: "CheckSessionEnv", message: "Reload account from remote then register necessaries")
        AccountAPI.me { [weak self] result in
            switch result {
            case .success(let account):
                LoginManager.shared.setAccount(account)
                self?.check(freshAccount: account)
            case .failure(let error):
                guard let self else {
                    return
                }
                Logger.login.error(category: "CheckSessionEnv", message: "Unable to reload account: \(error)")
                self.reportFailure(
                    description: error.localizedDescription,
                    retryWithSelector: #selector(reloadAccountThenRegisterNecessaries)
                )
            }
        }
    }
    
    private func registerNecessaries() {
        assert(Thread.isMainThread)
        guard let pin else {
            Logger.login.info(category: "CheckSessionEnv", message: "Missing PIN when registering necessaries")
            validatePIN()
            return
        }
        Logger.login.info(category: "CheckSessionEnv", message: "Register necessaries for account: \(account.userID)")
        reportBusy()
        Task {
            do {
                let updatedAccount = try await TIP.registerToSafeIfNeeded(account: account, pin: pin)
                try await TIP.registerDefaultCommonWalletIfNeeded(pin: pin)
                await MainActor.run {
                    Logger.login.info(category: "CheckSessionEnv", message: "Necessaries registered")
                    check(freshAccount: updatedAccount ?? LoginManager.shared.account)
                }
            } catch {
                Logger.login.error(category: "CheckSessionEnv", message: "Registration failed: \(error)")
                await MainActor.run {
                    reportFailure(
                        description: error.localizedDescription,
                        retryWithSelector: #selector(reloadAccountThenRegisterNecessaries)
                    )
                }
            }
        }
    }
    
}

// MARK: - BIP-39 Related
extension CheckSessionEnvironmentViewController {
    
    func finishCheckingForBIP39Session(
        welcomeWalletID: String?,
        updateWalletSecretsWith mnemonics: BIP39MnemonicsGroup? = nil, // nil for not updating
    ) {
        Logger.login.info(category: "CheckSessionEnv", message: "BIP39 checking finished")
        if let mnemonics {
            var walletIDs: Set<String> = []
            for address in Web3AddressDAO.shared.addresses() {
                guard let path = address.path, !walletIDs.contains(address.walletID) else {
                    continue
                }
                do {
                    let path = try DerivationPath(string: path)
                    let derivation: BIP39Mnemonics.Derivation
                    switch address.chainID {
                    case ChainID.bitcoin:
                        derivation = try mnemonics.plain.checkedDerivationForBitcoin(path: path)
                    case ChainID.ethereum:
                        derivation = try mnemonics.plain.checkedDerivationForEVM(path: path)
                    case ChainID.solana:
                        derivation = try mnemonics.plain.checkedDerivationForSolana(path: path)
                    default:
                        continue
                    }
                    if address.destination == derivation.address {
                        walletIDs.insert(address.walletID)
                    }
                } catch {
                    continue
                }
            }
            for walletID in walletIDs {
                Logger.login.info(category: "CheckSessionEnv", message: "Saved mnemonics for wallet: \(walletID)")
                AppGroupKeychain.setImportedMnemonics(mnemonics.encrypted, forWalletID: walletID)
            }
        }
        if let id = welcomeWalletID {
            AppGroupUserDefaults.Wallet.lastSelectedWallet = .common(id: id)
        }
        finishChecking(initialTab: .wallet)
    }
    
    @objc private func markMnemonicsExported() {
        guard let pin else {
            // Not likely to happen as long as previous checks are fulfilled
            // Anyway, the PIN should be ready after the validation
            Logger.login.error(category: "CheckSessionEnv", message: "Export mnemonics with no PIN")
            validatePIN()
            return
        }
        Logger.login.info(category: "CheckSessionEnv", message: "Mark mnemonics exported")
        reportBusy()
        Task {
            do {
                let request = try await ExportSaltRequest(userID: account.userID, pin: pin)
                let account = try await AccountAPI.exportSalt(request: request)
                LoginManager.shared.setAccount(account)
                Logger.login.info(category: "CheckSessionEnv", message: "Marking finished")
                await MainActor.run {
                    check(freshAccount: account)
                }
            } catch {
                Logger.login.info(category: "CheckSessionEnv", message: "Unable to mark mnemonics exported: \(error)")
                await MainActor.run {
                    reportFailure(
                        description: error.localizedDescription,
                        retryWithSelector: #selector(markMnemonicsExported)
                    )
                }
            }
        }
    }
    
    @objc private func importBIP39Wallets() {
        guard let pin else {
            // Not likely to happen as long as previous checks are fulfilled
            // Anyway, the PIN should be ready after the validation
            Logger.login.error(category: "CheckSessionEnv", message: "Import BIP-39 Wallet with no PIN")
            validatePIN()
            return
        }
        Logger.login.info(category: "CheckSessionEnv", message: "Import BIP-39 Wallet")
        reportBusy()
        Task {
            do {
                let entropy: Data
                if let mnemonics = AppGroupKeychain.mnemonics {
                    Logger.login.info(category: "CheckSessionEnv", message: "Using mnemonics from KeyChain")
                    entropy = mnemonics
                } else {
                    Logger.login.info(category: "CheckSessionEnv", message: "Using custodial salt as mnemonics")
                    // For 12/24 Mnemonics users with phone number added
                    // They have `AppGroupKeychain.mnemonics` deleted by receiving account
                    // Use custodialSalt instead
                    entropy = try await TIP.custodialSalt(pin: pin)
                }
                let mnemonics = try BIP39Mnemonics(entropy: entropy)
                let importWalletKey = try await TIP.importedWalletEncryptionKey(pin: pin)
                let encryptedMnemonics = try EncryptedBIP39Mnemonics(
                    mnemonics: mnemonics,
                    key: importWalletKey
                )
                Logger.login.info(category: "CheckSessionEnv", message: "Fetch addresses")
                let fetch = AddWalletFetchAddressViewController(
                    mnemonics: mnemonics,
                    encryptedMnemonics: encryptedMnemonics,
                    behavior: .breaksOnImportedWalletFound({ [weak self] walletID in
                        self?.finishCheckingForBIP39Session(
                            welcomeWalletID: walletID,
                            updateWalletSecretsWith: (mnemonics, encryptedMnemonics),
                        )
                    })
                )
                let navigation = GeneralAppearanceNavigationController(rootViewController: fetch)
                navigation.delegate = navigationBarAppearanceUpdater
                reload(content: navigation)
            } catch {
                Logger.login.error(category: "CheckSessionEnv", message: "Import failed: \(error)")
                await MainActor.run {
                    reportFailure(
                        description: error.localizedDescription,
                        retryWithSelector: #selector(importBIP39Wallets)
                    )
                }
            }
        }
    }
    
}

// MARK: - UI Works
extension CheckSessionEnvironmentViewController {
    
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
    
    private func reportBusy() {
        removeContentViewController()
        retryButton?.removeFromSuperview()
        activityIndicator.startAnimating()
        descriptionLabel.text = R.string.localizable.initializing()
        descriptionLabel.textColor = R.color.text_tertiary()
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
        retryConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 36, bottom: 11, trailing: 36)
        retryConfig.cornerStyle = .capsule
        let button = UIButton(configuration: retryConfig)
        button.addTarget(self, action: retrySelector, for: .touchUpInside)
        bottomStackView.addArrangedSubview(button)
        self.retryButton = button
    }
    
}

// MARK: - Navigation Classes
extension CheckSessionEnvironmentViewController {
    
    private final class RestoreChatNavigationHandler: NSObject, UINavigationControllerDelegate {
        
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            if viewController is QRCodeScannerViewController && !navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(true, animated: animated)
            } else if !(viewController is QRCodeScannerViewController) && navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: animated)
            }
        }
        
        func navigationController(
            _ navigationController: UINavigationController,
            animationControllerFor operation: UINavigationController.Operation,
            from fromVC: UIViewController,
            to toVC: UIViewController
        ) -> UIViewControllerAnimatedTransitioning? {
            switch operation {
            case .push where toVC is PopupNavigationAnimating:
                PopInNavigationAnimator()
            case .pop where fromVC is PopupNavigationAnimating:
                PopOutNavigationAnimator()
            default:
                nil
            }
        }
        
    }
    
    private final class FetchWalletNavigationController: GeneralAppearanceNavigationController {
        
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            if viewController is QRCodeScannerViewController && !navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(true, animated: animated)
            } else if !(viewController is QRCodeScannerViewController) && navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(false, animated: animated)
            }
        }
        
        func navigationController(
            _ navigationController: UINavigationController,
            animationControllerFor operation: UINavigationController.Operation,
            from fromVC: UIViewController,
            to toVC: UIViewController
        ) -> UIViewControllerAnimatedTransitioning? {
            switch operation {
            case .push where toVC is PopupNavigationAnimating:
                PopInNavigationAnimator()
            case .pop where fromVC is PopupNavigationAnimating:
                PopOutNavigationAnimator()
            default:
                nil
            }
        }
        
    }
    
}
