import UIKit
import MixinServices

final class HomeContainerViewController: UIViewController {
    
    static let viewDidAppearNotification = Notification.Name("one.mixin.messenger.HomeContainerViewController.ViewDidAppear")
    
    let homeTabBarController: HomeTabBarController
    var homeNavigationController: HomeNavigationController {
        homeTabBarController.selectedNavigationController
    }
    
    let clipSwitcher = ClipSwitcher()
    let overlaysCoordinator = HomeOverlaysCoordinator()
    
    lazy var minimizedCallViewController: MinimizedCallViewController = {
        let controller: MinimizedCallViewController = makeAndAddOverlay()
        minimizedCallViewControllerIfLoaded = controller
        return controller
    }()
    
    lazy var minimizedClipSwitcherViewController: MinimizedClipSwitcherViewController = makeAndAddOverlay()
    lazy var minimizedPlaylistViewController: MinimizedPlaylistViewController = makeAndAddOverlay()
    
    override var childForStatusBarHidden: UIViewController? {
        topMostChild
    }
    
    override var childForStatusBarStyle: UIViewController? {
        topMostChild
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        topMostChild
    }
    
    public var topMostChild: UIViewController {
        if let switcher = clipSwitcher.fullscreenSwitcherIfLoaded, switcher.isShowing {
            return switcher
        } else {
            return homeTabBarController
        }
    }
    
    private(set) weak var minimizedCallViewControllerIfLoaded: MinimizedCallViewController?
    
    private let sessionReporter = SessionReporter()
    
    private var refreshAccountAfterViewAppears: Bool
    
    init(initialTab: HomeTabBarController.InitialTab) {
        homeTabBarController = HomeTabBarController(initialTab: initialTab)
        switch initialTab {
        case .chat:
            refreshAccountAfterViewAppears = false
        case .wallet:
            refreshAccountAfterViewAppears = true
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.general.info(category: "HomeContainer", message: "View did load with app state: \(UIApplication.shared.applicationStateString)")
        addChild(homeTabBarController)
        view.addSubview(homeTabBarController.view)
        homeTabBarController.view.snp.makeEdgesEqualToSuperview()
        homeTabBarController.didMove(toParent: self)
        
        if AppGroupUserDefaults.Crypto.isPrekeyLoaded,
           AppGroupUserDefaults.Crypto.isSessionSynchronized,
           !AppGroupUserDefaults.isClockSkewed,
           LoginManager.shared.account != nil
        {
            if UIApplication.shared.applicationState == .active {
                WebSocketService.shared.connect()
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
                ConcurrentJobQueue.shared.addJob(job: RefreshAllTokensJob())
            }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        sessionReporter.reportIfOutdated()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NotificationManager.shared.registerForRemoteNotificationsIfAuthorized()
            CallService.shared.registerForPushKitNotificationsIfAvailable()
        }
        if UIApplication.shared.applicationState != .background {
            if AppGroupUserDefaults.User.hasRecoverMedia {
                ConcurrentJobQueue.shared.addJob(job: RecoverMediaJob())
            }
            initializeFTSIfNeeded()
            refreshExternalSchemesIfNeeded()
            if SpotlightManager.isAvailable {
                SpotlightManager.shared.indexIfNeeded()
            }
            let job = SyncOutputsJob()
            ConcurrentJobQueue.shared.addJob(job: job)
        }
        clipSwitcher.loadClipsFromPreviousSession()
        WalletConnectService.shared.reloadSessions()
        Web3Chain.synchronize()
        DispatchQueue.global().async {
            let walletIDs = Web3WalletDAO.shared.walletIDs()
            for id in walletIDs {
                let jobs = [
                    SyncWeb3AddressJob(walletID: id),
                    RefreshWeb3WalletTokenJob(walletID: id),
                    SyncWeb3TransactionJob(walletID: id),
                ]
                for job in jobs {
                    ConcurrentJobQueue.shared.addJob(job: job)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if refreshAccountAfterViewAppears {
            refreshAccountAfterViewAppears = false
            if CheckTIPCountersJob.isTIPCounterChecked {
                ConcurrentJobQueue.shared.addJob(job: RefreshAccountJob())
            } else {
                ConcurrentJobQueue.shared.addJob(job: CheckTIPCountersJob())
            }
        }
        NotificationCenter.default.post(
            name: Self.viewDidAppearNotification,
            object: self
        )
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let overlays = overlaysCoordinator.visibleOverlays
        overlays.forEach { $0.alpha = 0 }
        coordinator.animate(alongsideTransition: nil) { (context) in
            overlays.forEach { $0.alpha = 1 }
        }
    }
    
    func presentOnTopMostPresentedController(_ viewControllerToPresent: UIViewController, animated: Bool) {
        var topMost: UIViewController = self
        while let next = topMost.presentedViewController, !next.isBeingDismissed {
            topMost = next
        }
        topMost.present(viewControllerToPresent, animated: true)
    }
    
    func showWalletViewController() {
        homeTabBarController.showWallet()
    }
    
    func presentMyQRCode() {
        guard let account = LoginManager.shared.account else {
            return
        }
        if let current = presentedViewController as? QRCodeViewController {
            if current.isShowingAccount {
                return
            } else {
                dismiss(animated: true)
            }
        }
        let qrCode = QRCodeViewController(account: account)
        present(qrCode, animated: true)
    }
    
    @objc private func applicationDidBecomeActive(_ sender: Notification) {
        initializeFTSIfNeeded()
        refreshExternalSchemesIfNeeded()
    }
    
}

extension HomeContainerViewController {
    
    private func initializeFTSIfNeeded() {
        guard !AppGroupUserDefaults.Database.isFTSInitialized else {
            return
        }
        ConcurrentJobQueue.shared.addJob(job: InitializeFTSJob())
    }
    
    private func refreshExternalSchemesIfNeeded() {
        if -AppGroupUserDefaults.User.externalSchemesRefreshDate.timeIntervalSinceNow > .day {
            ConcurrentJobQueue.shared.addJob(job: RefreshExternalSchemeJob())
        }
    }
    
}

extension HomeContainerViewController {
    
    private func makeAndAddOverlay<Controller: HomeOverlayViewController>() -> Controller {
        let controller = Controller()
        controller.view.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        addChild(controller)
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        controller.updateViewSize()
        controller.panningController.placeViewNextToLastOverlayOrTopRight()
        overlaysCoordinator.register(overlay: controller.view)
        return controller
    }
    
}
