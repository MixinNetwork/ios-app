import UIKit
import MixinServices

final class HomeTabBarController: UIViewController {
    
    private enum ChildID: Int {
        case chat = 0
        case wallet = 1
        case bot = 2
    }
    
    private(set) weak var selectedViewController: UIViewController?
    
    private let tabBar = TabBar()
    
    private let homeViewController = R.storyboard.home.home()!
    
    private lazy var walletViewController = R.storyboard.wallet.wallet()!
    private lazy var botsViewController = R.storyboard.home.apps()!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let shadowView = TopShadowView()
        shadowView.backgroundColor = .clear
        shadowView.isUserInteractionEnabled = false
        view.addSubview(shadowView)
        
        tabBar.tintColor = R.color.icon_tint()
        tabBar.backgroundColor = .background
        tabBar.items = [
            TabBar.Item(id: ChildID.chat.rawValue,
                        image: R.image.home_tab_chat()!,
                        selectedImage: R.image.home_tab_chat_selected()!),
            TabBar.Item(id: ChildID.wallet.rawValue,
                        image: R.image.home_tab_wallet()!,
                        selectedImage: R.image.home_tab_wallet_selected()!),
            TabBar.Item(id: ChildID.bot.rawValue,
                        image: R.image.home_tab_bot()!,
                        selectedImage: R.image.home_tab_bot_selected()!),
        ]
        tabBar.selectedIndex = 0
        tabBar.delegate = self
        view.addSubview(tabBar)
        
        tabBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        shadowView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(tabBar.snp.top)
            make.height.equalTo(20)
        }
        
        switchToChildAfterValidated(with: .chat)
    }
    
    func showWallet() {
        let walletID: ChildID = .wallet
        guard let index = tabBar.items.firstIndex(where: { $0.id == walletID.rawValue }) else {
            return
        }
        tabBar.selectedIndex = index
        switchToChildAfterValidated(with: walletID)
    }
    
    private func switchToChild(with id: ChildID) {
        let newChild: UIViewController
        switch id {
        case .chat:
            newChild = homeViewController
        case .wallet:
            newChild = walletViewController
        case .bot:
            newChild = botsViewController
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
    }
    
    private func switchToChildAfterValidated(with id: ChildID) {
        switch id {
        case .chat, .bot:
            switchToChild(with: id)
        case .wallet:
            switch TIP.status {
            case .ready, .needsMigrate:
                let shouldValidatePIN: Bool
                if let date = AppGroupUserDefaults.Wallet.lastPinVerifiedDate {
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
