import UIKit
import MixinServices

protocol HomeTabBarControllerChild {
    func viewControllerDidSwitchToFront()
}

final class HomeTabBarController: UIViewController {
    
    enum ChildID: Int {
        case chat = 0
        case wallet = 1
        case collectibles = 2
        case more = 3
    }
    
    private(set) weak var selectedViewController: UIViewController?
    
    private let tabBar = TabBar()
    
    private let homeViewController = R.storyboard.home.home()!
    
    private lazy var walletViewController = WalletViewController()
    private lazy var collectiblesViewController = CollectiblesViewController()
    private lazy var exploreViewController = ExploreViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBar.tintColor = R.color.icon_tint()
        tabBar.backgroundColor = .background
        tabBar.items = [
            TabBar.Item(id: ChildID.chat.rawValue,
                        image: R.image.home_tab_chat()!,
                        selectedImage: R.image.home_tab_chat_selected()!,
                        text: R.string.localizable.chat()),
            TabBar.Item(id: ChildID.wallet.rawValue,
                        image: R.image.home_tab_wallet()!,
                        selectedImage: R.image.home_tab_wallet_selected()!,
                        text: R.string.localizable.wallet()),
            TabBar.Item(id: ChildID.collectibles.rawValue,
                        image: R.image.home_tab_collectibles()!,
                        selectedImage: R.image.home_tab_collectibles_selected()!,
                        text: R.string.localizable.collectibles()),
            TabBar.Item(id: ChildID.more.rawValue,
                        image: R.image.home_tab_more()!,
                        selectedImage: R.image.home_tab_more_selected()!,
                        text: R.string.localizable.more()),
        ]
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
            newChild = walletViewController
        case .collectibles:
            newChild = collectiblesViewController
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
    }
    
    private func switchToChildAfterValidated(with id: ChildID) {
        switch id {
        case .chat, .collectibles, .more:
            switchToChild(with: id)
        case .wallet:
            switch TIP.status {
            case .ready, .needsMigrate:
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
            case .needsInitialize:
                let tip = TIPNavigationViewController(intent: .create, destination: .wallet)
                navigationController?.present(tip, animated: true)
            case .unknown:
                break
            }
        }
    }
    
}

extension HomeTabBarController: TabBarDelegate {
    
    func tabBar(_ tabBar: TabBar, didSelect item: TabBar.Item) {
        let id = ChildID(rawValue: item.id)!
        switchToChildAfterValidated(with: id)
    }
    
}
