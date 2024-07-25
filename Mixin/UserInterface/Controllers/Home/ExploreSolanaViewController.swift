import UIKit
import MixinServices

final class ExploreSolanaViewController: ExploreWeb3ViewController {
    
    init() {
        super.init(kind: .solana)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesDidUpdate(_:)), name: PropertiesDAO.propertyDidUpdateNotification, object: nil)
        let address: String? = PropertiesDAO.shared.unsafeValue(forKey: .solanaAddress)
        reloadData(address: address)
    }
    
    override func unlockAccount(_ sender: Any) {
        let unlock = UnlockSolanaAccountViewController()
        present(unlock, animated: true)
    }
    
    override func reloadData(address: String?) {
        super.reloadData(address: address)
        if let headerView = tableView.tableHeaderView as? Web3AccountHeaderView {
            headerView.addSwapButton(self, action: #selector(swap(_:)))
            let areTokensLoaded = !(tokens?.isEmpty ?? true)
            areTokensLoaded ? headerView.disableSwapButton() : headerView.enableSwapButton()
        }
    }
    
    override func tokensDidReload(_ tokens: [Web3Token]) {
        guard let headerView = tableView.tableHeaderView as? Web3AccountHeaderView else {
            return
        }
        tokens.isEmpty ? headerView.disableSwapButton() : headerView.enableSwapButton()
    }
    
    @objc private func swap(_ sender: Any) {
        guard let address, let tokens else {
            return
        }
        let swap = Web3SwapViewController(address: address, tokens: tokens)
        let container = ContainerViewController.instance(viewController: swap, title: R.string.localizable.swap())
        navigationController?.pushViewController(container, animated: true)
    }
    
    @objc private func propertiesDidUpdate(_ notification: Notification) {
        guard let change = notification.userInfo?[PropertiesDAO.Key.solanaAddress] as? PropertiesDAO.Change else {
            return
        }
        switch change {
        case .removed:
            reloadData(address: nil)
        case .saved(let convertibleAddress):
            let address = String(convertibleAddress)
            reloadData(address: address)
        }
    }
    
}
