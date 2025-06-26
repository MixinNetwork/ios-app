import UIKit
import MixinServices

protocol CheckSessionEnvironmentChild {
    
}

extension CheckSessionEnvironmentChild where Self: UIViewController {
    
    func checkSessionEnvironmentAgain(freshAccount: Account? = nil) {
        let checker = parent as? CheckSessionEnvironmentViewController
        ?? navigationController?.parent as? CheckSessionEnvironmentViewController
        if let checker {
            checker.check(freshAccount: freshAccount)
        } else {
            assertionFailure()
        }
    }
    
}

final class CheckSessionEnvironmentViewController: UIViewController {
    
    private(set) weak var contentViewController: UIViewController?
    
    private lazy var restoreChatNavigationHandler = RestoreChatNavigationHandler()
    
    private var account: Account
    private var isAccountFresh: Bool
    
    private var isUsernameJustInitialized = false
    
    private var allUsersInitialBots: [String] {
        [BotUserID.teamMixin]
    }
    
    init(freshAccount account: Account) {
        self.account = account
        self.isAccountFresh = true
        super.init(nibName: nil, bundle: nil)
    }
    
    init(localAccount account: Account) {
        self.account = account
        self.isAccountFresh = false
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        Logger.general.debug(category: "CheckSessionEnvironment", message: "View loaded with account fresh: \(isAccountFresh)")
        check()
    }
    
    func check(freshAccount: Account? = nil) {
        if let freshAccount {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Account refreshed")
            self.account = freshAccount
            self.isAccountFresh = true
        }
        Logger.general.debug(category: "CheckSessionEnvironment", message: "Check environments")
        if AppGroupUserDefaults.isClockSkewed {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Clock skewed")
            while UIApplication.shared.keyWindow?.subviews.last is BottomSheetView {
                UIApplication.shared.keyWindow?.subviews.last?.removeFromSuperview()
            }
            let clockSkew = ClockSkewViewController()
            reload(content: clockSkew)
        } else if account.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Create username")
            isUsernameJustInitialized = true
            let username = UsernameViewController()
            reload(content: username)
        } else if AppGroupUserDefaults.Account.canRestoreFromPhone {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Restore chat")
            let restore = RestoreChatViewController()
            let navigationController = GeneralAppearanceNavigationController(rootViewController: restore)
            navigationController.delegate = restoreChatNavigationHandler
            reload(content: navigationController)
        } else if DatabaseUpgradeViewController.needsUpgrade {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Upgrade db")
            let upgrade = DatabaseUpgradeViewController()
            reload(content: upgrade)
        } else if !SignalLoadingViewController.isLoaded {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Load Signal")
            let signalLoading = SignalLoadingViewController(isUsernameJustInitialized: isUsernameJustInitialized)
            signalLoading.onFinished = { [weak self] in
                guard let self else {
                    return
                }
                if !self.isUsernameJustInitialized {
                    Logger.general.debug(category: "CheckSessionEnvironment", message: "Sync contacts")
                    ContactAPI.syncContacts()
                }
                for id in self.allUsersInitialBots {
                    Logger.general.debug(category: "CheckSessionEnvironment", message: "Initialize bots")
                    let job = InitializeBotJob(userID: id)
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
                self.check()
            }
            reload(content: signalLoading)
        } else {
            let root: UIViewController
            if account.hasPIN {
                let isReady = account.hasSafe
                    && AppGroupUserDefaults.User.loginPINValidated
                    && Web3WalletDAO.shared.hasClassicWallet()
                if isReady {
                    Logger.general.debug(category: "CheckSessionEnvironment", message: "Go home")
                    root = HomeContainerViewController()
                } else {
                    Logger.general.debug(category: "CheckSessionEnvironment", message: "Load TIP with account: \(freshAccount != nil)")
                    let freshAccount = isAccountFresh ? account : nil
                    root = LoginPINStatusCheckingViewController(freshAccount: freshAccount)
                }
            } else {
                Logger.general.debug(category: "CheckSessionEnvironment", message: "Create PIN")
                root = TIPNavigationController(intent: .create)
            }
            AppDelegate.current.mainWindow.rootViewController = root
        }
    }
    
    private func reload(content: UIViewController) {
        if let content = contentViewController {
            content.willMove(toParent: nil)
            content.view.removeFromSuperview()
            content.removeFromParent()
        }
        addChild(content)
        view.addSubview(content.view)
        content.view.snp.makeEdgesEqualToSuperview()
        content.didMove(toParent: self)
        self.contentViewController = content
    }
    
}

extension CheckSessionEnvironmentViewController {
    
    private final class RestoreChatNavigationHandler: NSObject, UINavigationControllerDelegate {
        
        private lazy var presentFromBottomAnimator = PresentFromBottomAnimator()
        
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            if viewController is CameraViewController && !navigationController.isNavigationBarHidden {
                navigationController.setNavigationBarHidden(true, animated: animated)
            } else if !(viewController is CameraViewController) && navigationController.isNavigationBarHidden {
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
