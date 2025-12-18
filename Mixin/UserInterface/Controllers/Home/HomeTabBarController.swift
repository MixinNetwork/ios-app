import UIKit
import MixinServices

protocol HomeTabBarControllerChild {
    func viewControllerDidSwitchToFront()
}

final class HomeTabBarController: UIViewController {
    
    enum ChildID: Int, CaseIterable, CustomDebugStringConvertible {
        
        case chat = 0
        case wallet = 1
        case market = 2
        case more = 3
        
        var debugDescription: String {
            switch self {
            case .chat:
                "chat"
            case .wallet:
                "wallet"
            case .market:
                "market"
            case .more:
                "more"
            }
        }
        
    }
    
    private(set) weak var selectedViewController: UIViewController?
    
    private let tabBar = TabBar()
    
    private let homeViewController = R.storyboard.home.home()!
    
    private lazy var walletContainerViewController = WalletContainerViewController()
    private lazy var marketDashboardViewController = MarketDashboardViewController()
    private lazy var exploreViewController = ExploreViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBar.tintColor = R.color.icon_tint()
        tabBar.backgroundColor = .background
        tabBar.items = ChildID.allCases.map { id in
            switch id {
            case .chat:
                TabBar.Item(
                    id: id.rawValue,
                    image: R.image.home_tab_chat()!,
                    selectedImage: R.image.home_tab_chat_selected()!,
                    text: R.string.localizable.chats(),
                    badge: false
                )
            case .wallet:
                TabBar.Item(
                    id: id.rawValue,
                    image: R.image.home_tab_wallet()!,
                    selectedImage: R.image.home_tab_wallet_selected()!,
                    text: R.string.localizable.wallets(),
                    badge: false
                )
            case .market:
                TabBar.Item(
                    id: id.rawValue,
                    image: R.image.home_tab_market()!,
                    selectedImage: R.image.home_tab_market_selected()!,
                    text: R.string.localizable.markets(),
                    badge: false
                )
            case .more:
                TabBar.Item(
                    id: id.rawValue,
                    image: R.image.home_tab_more()!,
                    selectedImage: R.image.home_tab_more_selected()!,
                    text: R.string.localizable.more(),
                    badge: false
                )
            }
        }
        tabBar.selectedIndex = 0
        tabBar.delegate = self
        updateTabBarShadow(resolveColorUsing: traitCollection)
        tabBar.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.05).cgColor
        tabBar.layer.shadowOpacity = 1
        tabBar.layer.shadowRadius = 4
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -1)
        view.addSubview(tabBar)
        tabBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        switchToChildAfterValidated(with: .chat)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadItemBadges),
            name: BadgeManager.viewedNotification,
            object: nil
        )
        reloadItemBadges()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateTabBarShadow(resolveColorUsing: traitCollection)
        }
    }
    
    func switchTo(child: ChildID) {
        guard let index = tabBar.items.firstIndex(where: { $0.id == child.rawValue }) else {
            return
        }
        tabBar.selectedIndex = index
        switchToChildAfterValidated(with: child)
    }
    
    @objc private func reloadItemBadges() {
        let hasUnviewedWalletItem = [.walletSwitch, .trade, .buy, .addWallet]
            .lazy
            .map(BadgeManager.shared.hasViewed(identifier:))
            .contains(false)
        let hasUnviewedMoreItem = [.buy, .trade, .membership]
            .lazy
            .map(BadgeManager.shared.hasViewed(identifier:))
            .contains(false)
        
        var items = tabBar.items
        items[ChildID.wallet.rawValue].badge = hasUnviewedWalletItem
        items[ChildID.more.rawValue].badge = hasUnviewedMoreItem
        tabBar.items = items
    }
    
    private func updateTabBarShadow(resolveColorUsing traitCollection: UITraitCollection) {
        switch traitCollection.userInterfaceStyle {
        case .dark:
            tabBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.16).cgColor
        case .light, .unspecified:
            fallthrough
        @unknown default:
            tabBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
        }
    }
    
    private func switchToChild(with id: ChildID) {
        let newChild: UIViewController
        switch id {
        case .chat:
            newChild = homeViewController
        case .wallet:
            newChild = walletContainerViewController
        case .market:
            newChild = marketDashboardViewController
        case .more:
            newChild = exploreViewController
        }
        
        if let currentChild = selectedViewController {
            if currentChild == newChild {
                return
            } else {
                currentChild.willMove(toParent: nil)
                currentChild.view.removeFromSuperview()
                currentChild.removeFromParent()
            }
        }
        selectedViewController = newChild
        
        addChild(newChild)
        view.insertSubview(newChild.view, at: 0)
        newChild.view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(tabBar.snp.top)
        }
        newChild.didMove(toParent: self)
        if let newChild = newChild as? HomeTabBarControllerChild {
            newChild.viewControllerDidSwitchToFront()
        }
        title = switch id {
        case .chat:
            "Mixin"
        case .wallet:
            R.string.localizable.wallets()
        case .market:
            R.string.localizable.markets()
        case .more:
            R.string.localizable.more()
        }
    }
    
    private func switchToChildAfterValidated(with id: ChildID) {
        switch id {
        case .chat, .market, .more:
            switchToChild(with: id)
        case .wallet:
            let shouldValidatePIN: Bool
            if let date = AppGroupUserDefaults.Wallet.lastPINVerifiedDate {
                shouldValidatePIN = -date.timeIntervalSinceNow > AppGroupUserDefaults.Wallet.periodicPinVerificationInterval
            } else {
                AppGroupUserDefaults.Wallet.periodicPinVerificationInterval = PeriodicPinVerificationInterval.min
                shouldValidatePIN = true
            }
            if shouldValidatePIN {
                let validator = PinValidationViewController(onSuccess: { (_) in
                    self.switchToChild(with: .wallet)
                })
                present(validator, animated: true, completion: nil)
            } else {
                switchToChild(with: .wallet)
            }
        }
    }
    
}

extension HomeTabBarController: TabBarDelegate {
    
    func tabBar(_ tabBar: TabBar, didSelect item: TabBar.Item) {
        let id = ChildID(rawValue: item.id)!
        reporter.report(event: .homeTabSwitch, tags: ["method": id.debugDescription])
        switchToChildAfterValidated(with: id)
    }
    
}

extension HomeTabBarController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .hide
    }
    
}
