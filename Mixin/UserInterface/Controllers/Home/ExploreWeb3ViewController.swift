import UIKit
import Combine
import Alamofire
import MixinServices

final class ExploreWeb3ViewController: UIViewController {
    
    private let tableView = UITableView()
    private let chain: WalletConnectService.Chain
    
    private weak var lastAccountRequest: Request?
    
    private var address: String?
    
    private var tokens: [Web3Token]?
    
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
        tableView.register(R.nib.assetCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset.bottom = 10
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesDidUpdate(_:)), name: PropertiesDAO.propertyDidUpdateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateCurrency), name: Currency.currentCurrencyDidChangeNotification, object: nil)
        let address: String? = PropertiesDAO.shared.unsafeValue(forKey: .evmAddress)
        reloadData(address: address)
    }
    
    @IBAction func receive(_ sender: Any) {
        guard let address else {
            return
        }
        let deposit = Web3DepositViewController(address: address)
        let container = ContainerViewController.instance(viewController: deposit, title: R.string.localizable.receive())
        navigationController?.pushViewController(container, animated: true)
    }
    
    func reloadAccountIfUnlocked() {
        guard let address, lastAccountRequest == nil else {
            return
        }
        reloadAccount(address: address)
    }
    
    @objc private func propertiesDidUpdate(_ notification: Notification) {
        guard let change = notification.userInfo?[PropertiesDAO.Key.evmAddress] as? PropertiesDAO.Change else {
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
    
    @objc private func updateCurrency(_ notification: Notification) {
        guard let address else {
            return
        }
        reloadData(address: address)
    }
    
    @objc private func unlockAccount(_ sender: Any) {
        let unlock = UnlockWeb3WalletViewController(chain: chain)
        present(unlock, animated: true)
    }
    
    @objc private func send(_ sender: Any) {
        showAutoHiddenHud(style: .warning, text: "Comming Soon")
    }
    
    @objc private func browse(_ sender: Any) {
        guard let explore = parent as? ExploreViewController else {
            return
        }
        let browser = Web3BrowserViewController(chain: chain)
        explore.presentSearch(with: browser)
    }
    
    @objc private func more(_ sender: Any) {
        guard let address else {
            return
        }
        let sheet = UIAlertController(title: R.string.localizable.web3_account_network(chain.name), 
                                      message: Address.compactRepresentation(of: address),
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.copy_address(), style: .default, handler: { _ in
            UIPasteboard.general.string = address
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        present(sheet, animated: true)
    }
    
    private func reloadData(address: String?) {
        self.address = address
        if let address {
            let tableHeaderView = R.nib.web3AccountHeaderView(withOwner: nil)!
            tableHeaderView.addAction(title: R.string.localizable.caption_send(),
                                      icon: R.image.web3_action_send()!,
                                      target: self,
                                      action: #selector(send(_:)))
            tableHeaderView.addAction(title: R.string.localizable.receive(),
                                      icon: R.image.web3_action_receive()!,
                                      target: self,
                                      action: #selector(receive(_:)))
            tableHeaderView.addAction(title: R.string.localizable.browser(),
                                      icon: R.image.web3_action_browser()!,
                                      target: self,
                                      action: #selector(browse(_:)))
            tableHeaderView.addAction(title: R.string.localizable.more(),
                                      icon: R.image.web3_action_more()!,
                                      target: self,
                                      action: #selector(more(_:)))
            tableView.tableHeaderView = tableHeaderView
            reloadAccount(address: address)
        } else {
            let tableHeaderView = R.nib.web3AccountLockedHeaderView(withOwner: nil)!
            tableHeaderView.showUnlockAccount(chain: chain)
            tableHeaderView.button.addTarget(self, action: #selector(unlockAccount(_:)), for: .touchUpInside)
            tableView.tableHeaderView = tableHeaderView
            tokens = nil
            tableView.reloadData()
        }
    }
    
    private func reloadAccount(address: String) {
        Logger.web3.debug(category: "Explore", message: "Reloading with: \(address)")
        let chainName = chain.name
        let noData = if let tokens {
            tokens.isEmpty
        } else {
            true
        }
        if noData {
            tableView.tableFooterView = R.nib.loadingIndicatorTableFooterView(withOwner: nil)!
        }
        lastAccountRequest?.cancel()
        lastAccountRequest = Web3API.account(address: address) { result in
            switch result {
            case .success(let account):
                self.tokens = account.tokens
                self.tableView.reloadData()
                if let headerView = self.tableView.tableHeaderView as? Web3AccountHeaderView {
                    headerView.setNetworkName(chainName)
                    headerView.amountLabel.text = account.localizedFiatMoneyBalance
                }
                self.tableView.tableFooterView = if account.tokens.isEmpty {
                    R.nib.web3NoAssetView(withOwner: self)
                } else {
                    nil
                }
            case .failure(.requiresUpdate):
                let alert = UIAlertController(title: R.string.localizable.update_mixin(),
                                              message: R.string.localizable.app_update_tips(Bundle.main.shortVersion),
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: R.string.localizable.later(), style: .default, handler: { _ in
                    UIApplication.shared.openAppStorePage()
                }))
                alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: { _ in
                    (self.parent as? ExploreViewController)?.switchToSegment(.bots)
                }))
                self.present(alert, animated: true)
                self.tableView.tableFooterView = nil
            case .failure(let error):
                Logger.web3.debug(category: "Explore", message: "\(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.reloadAccount(address: address)
                }
            }
        }
    }
    
}

// MARK: - UITableViewDataSource
extension ExploreWeb3ViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokens?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        if let token = tokens?[indexPath.row] {
            cell.render(web3Token: token)
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension ExploreWeb3ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}
