import UIKit
import MixinServices

final class CheckSessionEnvironmentViewController: UIViewController {
    
    private var account: Account
    private var isAccountFresh: Bool
    
    private var isUsernameJustInitialized = false
    
    private var allUsersInitialBots: [String] {
        [BotUserID.teamMixin]
    }
    
    private(set) weak var contentViewController: UIViewController?
    
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
            reload(content: navigationController)
        } else if DatabaseUpgradeViewController.needsUpgrade {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Upgrade db")
            let upgrade = DatabaseUpgradeViewController()
            reload(content: upgrade)
        } else if !SignalLoadingViewController.isLoaded {
            Logger.general.debug(category: "CheckSessionEnvironment", message: "Load Signal")
            let signalLoading = SignalLoadingViewController()
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
            switch TIP.Status(account: account) {
            case .ready:
                if AppGroupUserDefaults.User.isTIPInitialized {
                    Logger.general.debug(category: "CheckSessionEnvironment", message: "Go home")
                    root = HomeContainerViewController()
                } else {
                    let freshAccount = isAccountFresh ? account : nil
                    Logger.general.debug(category: "CheckSessionEnvironment", message: "Load TIP with account: \(freshAccount != nil)")
                    root = TIPLoadingViewController(freshAccount: freshAccount)
                }
            case .needsInitialize:
                Logger.general.debug(category: "CheckSessionEnvironment", message: "Create PIN")
                root = TIPNavigationViewController(intent: .create, destination: .home)
            case .needsMigrate:
                Logger.general.debug(category: "CheckSessionEnvironment", message: "Legacy PIN")
                root = LegacyPINViewController()
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
