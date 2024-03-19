import UIKit
import MixinServices

final class Web3WalletViewController: UIViewController {
    
    struct Dapp {
        
        static let uniswap = Dapp(
            name: "Uniswap",
            host: "app.uniswap.org",
            url: URL(string: "https://app.uniswap.org")!,
            icon: "🦄"
        )
        
        static let snapshot = Dapp(
            name: "Snapshot",
            host: "snapshot.org",
            url: URL(string: "https://snapshot.org")!,
            icon: "⚡️"
        )
        
        let name: String
        let host: String
        let url: URL
        let icon: String
        
    }
    
    private let tableView = UITableView()
    private let tableHeaderView = R.nib.web3WalletHeaderView(withOwner: nil)!
    private let chain: WalletConnectService.Chain
    private let dapps: [Dapp] = [.uniswap, .snapshot]
    
    private var address: String?
    
    init(chain: WalletConnectService.Chain) {
        self.chain = chain
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.backgroundColor = R.color.background()
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        tableView.register(R.nib.web3DappCell)
        tableView.dataSource = self
        tableView.delegate = self
        
        tableHeaderView.showUnlockAccount(chain: chain)
        tableHeaderView.frame.size.height = 134
        tableHeaderView.delegate = self
        tableView.tableHeaderView = tableHeaderView
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(propertiesDidUpdate(_:)),
                                               name: PropertiesDAO.propertyDidUpdateNotification,
                                               object: nil)
        DispatchQueue.global().async { [chain] in
            let address: String? = PropertiesDAO.shared.value(forKey: .evmAccount)
            DispatchQueue.main.async {
                if address == nil {
                    self.tableHeaderView.showUnlockAccount(chain: chain)
                } else {
                    self.tableHeaderView.showCopyAddress(chain: chain)
                }
            }
        }
    }
    
    @objc private func propertiesDidUpdate(_ notification: Notification) {
        address = notification.userInfo?[PropertiesDAO.Key.evmAccount] as? String
        if address != nil {
            tableHeaderView.showCopyAddress(chain: chain)
        }
    }
    
}

// MARK: - Web3WalletHeaderView Delegate
extension Web3WalletViewController: Web3WalletHeaderView.Delegate {
    
    func web3WalletHeaderViewRequestToCreateAccount(_ view: Web3WalletHeaderView) {
        let unlock = UnlockWeb3WalletViewController(chain: chain)
        present(unlock, animated: true)
    }
    
    func web3WalletHeaderViewRequestToCopyAddress(_ view: Web3WalletHeaderView) {
        guard let address: String = PropertiesDAO.shared.value(forKey: .evmAccount) else {
            return
        }
        UIPasteboard.general.string = address
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

// MARK: - UITableViewDataSource
extension Web3WalletViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dapps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_dapp, for: indexPath)!
        let dapp = dapps[indexPath.row]
        cell.iconLabel.text = dapp.icon
        cell.nameLabel.text = dapp.name
        cell.hostLabel.text = dapp.host
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension Web3WalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let container = UIApplication.homeContainerViewController?.homeTabBarController {
            let dapp = dapps[indexPath.row]
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: dapp.url), asChildOf: container)
        }
    }
    
}
