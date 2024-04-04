import UIKit
import Combine
import MixinServices

final class Web3WalletViewController: UIViewController {
    
    private let tableView = UITableView()
    private let tableHeaderView = R.nib.web3WalletHeaderView(withOwner: nil)!
    private let chain: WalletConnectService.Chain
    
    private var dapps: [Web3Dapp]?
    private var sessions: [WalletConnectSession] = []
    
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
        tableView.contentInset.bottom = 10
        
        if let web3Chains = Web3Chain.global {
            reloadDapps(web3Chains: web3Chains)
        } else {
            // Loading in progress by `Web3Chain.synchronize`. Wait for the updated notification
            let footerView = R.nib.loadingIndicatorTableFooterView(withOwner: nil)!
            tableView.tableFooterView = footerView
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadDapps(notification:)),
                                               name: Web3Chain.globalChainsDidUpdateNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(propertiesDidUpdate(_:)),
                                               name: PropertiesDAO.propertyDidUpdateNotification,
                                               object: nil)
        address = PropertiesDAO.shared.value(forKey: .evmAddress)
        if let address {
            tableHeaderView.showCopyAddress(chain: chain, address: address)
        } else {
            tableHeaderView.showUnlockAccount(chain: chain)
        }
        tableHeaderView.delegate = self
        tableView.tableHeaderView = tableHeaderView
    }
    
    @objc private func reloadDapps(notification: Notification) {
        guard let web3Chains = Web3Chain.global else {
            return
        }
        reloadDapps(web3Chains: web3Chains)
    }
    
    @objc private func propertiesDidUpdate(_ notification: Notification) {
        guard let change = notification.userInfo?[PropertiesDAO.Key.evmAddress] as? PropertiesDAO.Change else {
            return
        }
        switch change {
        case .removed:
            self.address = nil
            tableHeaderView.showUnlockAccount(chain: chain)
        case .saved(let convertibleAddress):
            let address = String(convertibleAddress)
            self.address = address
            tableHeaderView.showCopyAddress(chain: chain, address: address)
        }
    }
    
    private func reloadDapps(web3Chains: [String: Web3Chain]) {
        tableView.tableFooterView = nil
    }
    
}

// MARK: - Web3WalletHeaderView Delegate
extension Web3WalletViewController: Web3WalletHeaderView.Delegate {
    
    func web3WalletHeaderViewRequestToCreateAccount(_ view: Web3WalletHeaderView) {
        let unlock = UnlockWeb3WalletViewController(chain: chain)
        present(unlock, animated: true)
    }
    
    func web3WalletHeaderViewRequestToCopyAddress(_ view: Web3WalletHeaderView) {
        guard let address else {
            return
        }
        UIPasteboard.general.string = address
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

// MARK: - UITableViewDataSource
extension Web3WalletViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dapps?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_dapp, for: indexPath)!
        if let dapp = dapps?[indexPath.row] {
            cell.iconImageView.sd_setImage(with: dapp.iconURL)
            cell.nameLabel.text = dapp.name
            cell.hostLabel.text = dapp.host
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension Web3WalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let container = UIApplication.homeContainerViewController?.homeTabBarController, let url = dapps?[indexPath.row].homeURL {
            MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url),
                                                   asChildOf: container)
        }
    }
    
}
