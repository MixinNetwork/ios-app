import UIKit
import MixinServices

final class HomeTabBarController: UITabBarController {
    
    enum InitialTab {
        case chat
        case wallet
    }
    
    private let homeViewController = R.storyboard.home.home()!
    private let walletContainerViewController = WalletContainerViewController()
    private let marketDashboardViewController = MarketDashboardViewController()
    private let exploreViewController = ExploreViewController()
    
    private lazy var chatNavigationController = HomeNavigationController(
        rootViewController: homeViewController,
    )
    private lazy var walletNavigationController = HomeNavigationController(
        rootViewController: walletContainerViewController,
    )
    private lazy var marketNavigationController = HomeNavigationController(
        rootViewController: marketDashboardViewController,
    )
    private lazy var exploreNavigationController = HomeNavigationController(
        rootViewController: exploreViewController,
    )
    
    var selectedNavigationController: HomeNavigationController {
        loadViewIfNeeded()
        return selectedViewController as? HomeNavigationController ?? chatNavigationController
    }
    
    override var childForStatusBarHidden: UIViewController? {
        selectedViewController
    }
    
    override var childForStatusBarStyle: UIViewController? {
        selectedViewController
    }
    
    override var childForHomeIndicatorAutoHidden: UIViewController? {
        selectedViewController
    }
    
    private lazy var unlockableWalletChain: UnlockableCommonWalletChain? = {
        if Web3WalletDAO.shared
            .chainUnavailableWallets(chainID: ChainID.bitcoin)
            .contains(where: { $0.hasSecret() })
        {
            return .bitcoin
        }
        if Web3WalletDAO.shared
            .chainUnavailableWallets(chainID: ChainID.pearl)
            .contains(where: { $0.hasSecret() })
        {
            return .pearl
        }
        return nil
    }()
    
    private var pendingInitialWalletValidation: Bool
    
    init(initialTab: InitialTab) {
        pendingInitialWalletValidation = initialTab == .wallet
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        let tintColor = R.color.icon_tint()
        tabBar.tintColor = tintColor
        tabBar.unselectedItemTintColor = tintColor
        let appearance = tabBar.standardAppearance
        for itemAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            itemAppearance.normal.iconColor = tintColor
            itemAppearance.selected.iconColor = tintColor
            itemAppearance.normal.titleTextAttributes[.foregroundColor] = tintColor
            itemAppearance.selected.titleTextAttributes[.foregroundColor] = tintColor
            itemAppearance.normal.badgeBackgroundColor = .clear
            itemAppearance.normal.badgeTextAttributes = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: R.color.error_red()!,
            ]
            itemAppearance.selected.badgeBackgroundColor = .clear
            itemAppearance.selected.badgeTextAttributes = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: R.color.error_red()!,
            ]
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        
        chatNavigationController.tabBarItem = UITabBarItem(
            title: R.string.localizable.chats(),
            image: R.image.home_tab_chat(),
            selectedImage: R.image.home_tab_chat_selected(),
        )
        walletNavigationController.tabBarItem = UITabBarItem(
            title: R.string.localizable.wallets(),
            image: R.image.home_tab_wallet(),
            selectedImage: R.image.home_tab_wallet_selected(),
        )
        marketNavigationController.tabBarItem = UITabBarItem(
            title: R.string.localizable.markets(),
            image: R.image.home_tab_market(),
            selectedImage: R.image.home_tab_market_selected(),
        )
        exploreNavigationController.tabBarItem = UITabBarItem(
            title: R.string.localizable.more(),
            image: R.image.home_tab_more(),
            selectedImage: R.image.home_tab_more_selected(),
        )
        viewControllers = [
            chatNavigationController,
            walletNavigationController,
            marketNavigationController,
            exploreNavigationController,
        ]
        customizableViewControllers = nil
        if pendingInitialWalletValidation {
            selectedViewController = walletNavigationController
        }
        updateSelectionAppearance()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadItemBadges),
            name: BadgeManager.viewedNotification,
            object: nil
        )
        reloadItemBadges()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if pendingInitialWalletValidation {
            showWallet()
        }
    }
    
    func showWallet() {
        loadViewIfNeeded()
        pendingInitialWalletValidation = false
        if shouldSelectWallet() {
            selectWallet()
        }
    }
    
    @objc private func reloadItemBadges() {
        if BadgeManager.shared.hasViewed(identifier: .moreTab) {
            exploreNavigationController.tabBarItem.badgeValue = nil
        } else {
            exploreNavigationController.tabBarItem.badgeValue = "●"
        }
    }
    
    private func selectWallet() {
        guard selectedViewController !== walletNavigationController else {
            return
        }
        selectedViewController = walletNavigationController
        updateSelectionAppearance()
    }
    
    private func updateSelectionAppearance() {
        guard let selectedViewController else {
            return
        }
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        if selectedViewController === exploreNavigationController {
            BadgeManager.shared.setHasViewed(identifier: .moreTab)
        }
    }
    
    private func shouldSelectWallet() -> Bool {
        guard presentedViewController == nil else {
            return false
        }
        
        if let unlockableWalletChain {
            let unlock = UnlockCommonWalletChainsNavigationController(content: unlockableWalletChain)
            unlock.onSuccess = { [weak self] in
                guard let self else {
                    return
                }
                self.unlockableWalletChain = nil
                self.selectWallet()
            }
            present(unlock, animated: true)
            return false
        }
        
        let shouldValidatePIN: Bool
        if let date = AppGroupUserDefaults.Wallet.lastPINVerifiedDate {
            shouldValidatePIN = -date.timeIntervalSinceNow > AppGroupUserDefaults.Wallet.periodicPinVerificationInterval
        } else {
            AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
            shouldValidatePIN = true
        }
        if shouldValidatePIN {
            let validator = PinValidationViewController(onSuccess: { [weak self] _ in
                self?.selectWallet()
            })
            present(validator, animated: true)
            return false
        }
        
        return true
    }
    
}

extension HomeTabBarController: UITabBarControllerDelegate {
    
    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController,
    ) -> Bool {
        let method: String
        switch viewController {
        case chatNavigationController:
            method = "chats"
        case walletNavigationController:
            method = "wallets"
        case marketNavigationController:
            method = "markets"
        case exploreNavigationController:
            method = "more"
        default:
            return false
        }
        reporter.report(event: .homeTabSwitch, tags: ["method": method])
        return viewController !== walletNavigationController || shouldSelectWallet()
    }
    
    func tabBarController(
        _ tabBarController: UITabBarController,
        didSelect viewController: UIViewController,
    ) {
        updateSelectionAppearance()
    }
    
}
