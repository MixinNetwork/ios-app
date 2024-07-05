import UIKit
import MixinServices

final class ExploreSolanaViewController: ExploreWeb3ViewController {
    
    private var swappingOutdated = false
    private var swappableTokens: [Web3SwappableToken]?
    
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
        reloadSwappableTokens()
    }
    
    override func unlockAccount(_ sender: Any) {
        let unlock = UnlockSolanaAccountViewController()
        present(unlock, animated: true)
    }
    
    override func reloadData(address: String?) {
        super.reloadData(address: address)
        if let headerView = tableView.tableHeaderView as? Web3AccountHeaderView {
            headerView.addSwapButton(self, action: #selector(swap(_:)))
        }
        updateSwapButton()
    }
    
    override func tokensDidReload() {
        super.tokensDidReload()
        updateSwapButton()
    }
    
    @objc private func swap(_ sender: Any) {
        if swappingOutdated {
            let alert = UIAlertController(title: R.string.localizable.update_mixin(),
                                          message: R.string.localizable.app_update_tips(Bundle.main.shortVersion),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.update(), style: .default, handler: { _ in
                UIApplication.shared.openAppStorePage()
            }))
            alert.addAction(UIAlertAction(title: R.string.localizable.later(), style: .cancel, handler: nil))
            self.present(alert, animated: true)
            return
        }
        guard
            let address,
            let payTokens = tokens,
            !payTokens.isEmpty,
            let receiveTokens = swappableTokens,
            !receiveTokens.isEmpty
        else {
            return
        }
        let swap = Web3SwapViewController(address: address, payTokens: payTokens, receiveTokens: receiveTokens)
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
    
    private func updateSwapButton() {
        guard let headerView = tableView.tableHeaderView as? Web3AccountHeaderView else {
            return
        }
        let hasPayTokens = !(tokens?.isEmpty ?? true)
        let hasReceiveTokens = !(swappableTokens?.isEmpty ?? true)
        if swappingOutdated || (hasPayTokens && hasReceiveTokens) {
            headerView.enableSwapButton()
        } else {
            headerView.disableSwapButton()
        }
    }
    
    private func reloadSwappableTokens() {
        RouteAPI.swappableTokens { [weak self] result in
            switch result {
            case .success(let tokens):
                guard let self else {
                    return
                }
                self.swappingOutdated = false
                self.swappableTokens = tokens
                self.updateSwapButton()
            case .failure(.requiresUpdate):
                self?.swappingOutdated = true
            case .failure(let error):
                Logger.general.debug(category: "ExploreSolana", message: error.localizedDescription)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self?.reloadSwappableTokens()
                }
            }
        }
    }
    
}
