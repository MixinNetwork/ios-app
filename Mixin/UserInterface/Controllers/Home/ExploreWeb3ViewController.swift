import UIKit
import Combine
import Alamofire
import web3
import MixinServices

class ExploreWeb3ViewController: UIViewController {
    
    let tableView = UITableView()
    
    private(set) var address: String?
    private(set) var tokens: [Web3Token]?
    
    private let kind: Web3Chain.Kind
    
    private weak var lastAccountRequest: Request?
    
    init(kind: Web3Chain.Kind) {
        self.kind = kind
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
        tableView.rowHeight = 74
        tableView.separatorStyle = .none
        tableView.register(R.nib.assetCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset.bottom = 10
        NotificationCenter.default.addObserver(self, selector: #selector(updateCurrency), name: Currency.currentCurrencyDidChangeNotification, object: nil)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            layoutTableHeaderView()
        }
    }
    
    func reloadAccountIfUnlocked() {
        guard let address, lastAccountRequest == nil else {
            return
        }
        reloadAccount(address: address)
    }
    
    @objc func unlockAccount(_ sender: Any) {
        fatalError("Must override")
    }
    
    @objc private func updateCurrency(_ notification: Notification) {
        guard let address else {
            return
        }
        reloadData(address: address)
    }
    
    @objc private func send(_ sender: Any) {
        guard let tokens else {
            return
        }
        let selector = Web3TokenSelectorViewController(tokens: tokens)
        selector.onSelected = { token in
            guard let address = self.address, let chain = Web3Chain.chain(web3ChainID: token.chainID) else {
                return
            }
            let payment = Web3SendingTokenPayment(chain: chain, token: token, fromAddress: address)
            let selector = Web3TokenReceiverViewController(payment: payment)
            self.navigationController?.pushViewController(selector, animated: true)
        }
        present(selector, animated: true)
    }
    
    @objc private func receive(_ sender: Any) {
        guard let address else {
            return
        }
        let source = Web3ReceiveSourceViewController(kind: kind, address: address)
        navigationController?.pushViewController(source, animated: true)
    }
    
    @objc private func browse(_ sender: Any) {
        guard let explore = parent as? ExploreViewController else {
            return
        }
        let browser = Web3BrowserViewController(kind: kind)
        explore.presentSearch(with: browser)
    }
    
    @objc private func more(_ sender: Any) {
        guard let address else {
            return
        }
        let chainName = kind.chains[0].name
        let sheet = UIAlertController(title: R.string.localizable.web3_account_network(chainName),
                                      message: Address.compactRepresentation(of: address),
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.copy_address(), style: .default, handler: { _ in
            UIPasteboard.general.string = address
            showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel))
        present(sheet, animated: true)
    }
    
    func tokensDidReload(_ tokens: [Web3Token]) {
        
    }
    
    func reloadData(address: String?) {
        self.address = address
        let chain = kind.chains[0]
        if let address {
            let tableHeaderView = R.nib.web3AccountHeaderView(withOwner: nil)!
            tableHeaderView.addTarget(self,
                                      send: #selector(send(_:)),
                                      receive: #selector(receive(_:)),
                                      browse: #selector(browse(_:)),
                                      more: #selector(more(_:)))
            tableHeaderView.disableSendButton()
            tableHeaderView.setNetworkName(chain.name)
            tableView.tableHeaderView = tableHeaderView
            layoutTableHeaderView()
            reloadAccount(address: address)
        } else {
            let tableHeaderView = R.nib.web3AccountLockedHeaderView(withOwner: nil)!
            tableHeaderView.showUnlockAccount(chain: chain)
            tableHeaderView.button.addTarget(self, action: #selector(unlockAccount(_:)), for: .touchUpInside)
            tableView.tableHeaderView = tableHeaderView
            layoutTableHeaderView()
            tokens = nil
            tableView.reloadData()
        }
    }
    
    private func layoutTableHeaderView() {
        guard let tableHeaderView = tableView.tableHeaderView else {
            return
        }
        let sizeToFit = CGSize(width: tableHeaderView.frame.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let height = tableHeaderView.systemLayoutSizeFitting(sizeToFit).height
        tableHeaderView.frame.size.height = height
        tableView.tableHeaderView = tableHeaderView
    }
    
    private func reloadAccount(address: String) {
        Logger.web3.debug(category: "Explore", message: "Reloading with: \(address)")
        if tokens?.isEmpty ?? true {
            tableView.tableFooterView = R.nib.loadingIndicatorTableFooterView(withOwner: nil)!
        }
        lastAccountRequest?.cancel()
        lastAccountRequest = Web3API.account(address: address) { result in
            switch result {
            case .success(let account):
                self.tokens = account.tokens
                self.tableView.reloadData()
                if let headerView = self.tableView.tableHeaderView as? Web3AccountHeaderView {
                    headerView.amountLabel.text = account.localizedFiatMoneyBalance
                    headerView.enableSendButton()
                }
                self.tableView.tableFooterView = if account.tokens.isEmpty {
                    R.nib.web3NoAssetView(withOwner: self)
                } else {
                    nil
                }
                self.tokensDidReload(account.tokens)
            case .failure(.requiresUpdate):
                let alert = UIAlertController(title: R.string.localizable.update_mixin(),
                                              message: R.string.localizable.app_update_tips(Bundle.main.shortVersionString),
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: R.string.localizable.update(), style: .default, handler: { _ in
                    UIApplication.shared.openAppStorePage()
                }))
                alert.addAction(UIAlertAction(title: R.string.localizable.later(), style: .cancel, handler: { _ in
                    (self.parent as? ExploreViewController)?.switchToSegment(.bots)
                }))
                self.present(alert, animated: true)
                self.tableView.tableFooterView = nil
            case .failure(.httpTransport(.explicitlyCancelled)):
                break
            case .failure(let error):
                Logger.web3.error(category: "Explore", message: "\(error)")
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
        if let address, let token = tokens?[indexPath.row] {
            let viewController = Web3TokenViewController(kind: kind, address: address, token: token)
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
}
