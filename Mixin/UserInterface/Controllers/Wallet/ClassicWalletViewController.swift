import UIKit
import MixinServices

final class ClassicWalletViewController: WalletViewController {
    
    private let walletID: String
    
    private var tokens: [Web3TokenItem] = []
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.common_wallet()
        tableView.dataSource = self
        tableView.delegate = self
        tableHeaderView.actionView.swapButton.isHidden = true
        tableHeaderView.actionView.delegate = self
        tableHeaderView.pendingDepositButton.addTarget(
            self,
            action: #selector(revealPendingDeposits(_:)),
            for: .touchUpInside
        )
        let notificationCenter: NotificationCenter = .default
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadDataIfWalletMatch(_:)),
            name: Web3TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadTokensFromRemote),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(reloadPendingDeposits),
            name: Web3TransactionDAO.transactionDidSaveNotification,
            object: nil
        )
        reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadTokensFromRemote()
    }
    
    override func moreAction(_ sender: Any) {
        let walletID = self.walletID
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: R.string.localizable.all_transactions(), style: .default, handler: { (_) in
            let history = Web3TransactionHistoryViewController(walletID: walletID, type: nil)
            self.navigationController?.pushViewController(history, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.hidden_assets(), style: .default, handler: { (_) in
            let hidden = HiddenWeb3TokensViewController(walletID: walletID)
            self.navigationController?.pushViewController(hidden, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    override func makeSearchViewController() -> WalletSearchViewController {
        let ids = Set(Web3Chain.all.map(\.chainID))
        let controller = WalletSearchViewController(supportedChainIDs: ids)
        controller.delegate = self
        return controller
    }
    
    @objc private func reloadTokensFromRemote() {
        let syncTokens = RefreshWeb3TokenJob(walletID: walletID)
        ConcurrentJobQueue.shared.addJob(job: syncTokens)
        
        let syncTransactions = SyncWeb3TransactionJob(walletID: walletID)
        ConcurrentJobQueue.shared.addJob(job: syncTransactions)
        
        let syncPendingTransactions = ReviewPendingWeb3TransactionJob()
        ConcurrentJobQueue.shared.addJob(job: syncPendingTransactions)
    }
    
    @objc private func reloadDataIfWalletMatch(_ notification: Notification) {
        guard let id = notification.userInfo?[Web3TokenDAO.walletIDUserInfoKey] as? String else {
            return
        }
        guard id == walletID else {
            return
        }
        reloadData()
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [walletID, weak self] in
            let tokens = Web3TokenDAO.shared.notHiddenTokens(walletID: walletID)
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.tokens = tokens
                self.tableHeaderView.reloadValues(tokens: tokens)
                self.layoutTableHeaderView()
                self.tableView.reloadData()
            }
        }
    }
    
    @objc private func reloadPendingDeposits() {
        DispatchQueue.global().async { [weak self] in
            let transactions = Web3TransactionDAO.shared.pendingTransactions()
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.tableHeaderView.reloadPendingTransactions(transactions)
                self.layoutTableHeaderView()
            }
        }
    }
    
    @objc private func revealPendingDeposits(_ sender: Any) {
        let transactionHistory = Web3TransactionHistoryViewController(walletID: walletID, type: .pending)
        navigationController?.pushViewController(transactionHistory, animated: true)
    }
    
    private func hideToken(with assetID: String) {
        guard let index = tokens.firstIndex(where: { $0.assetID == assetID }) else {
            return
        }
        let token = tokens.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
        DispatchQueue.global().async { [walletID] in
            Web3TokenExtraDAO.shared.hide(walletID: walletID, assetID: token.assetID)
        }
    }
    
}

extension ClassicWalletViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = tokens[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(web3Token: token)
        return cell
    }
    
}

extension ClassicWalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = tokens[indexPath.row]
        let viewController = Web3TokenViewController(token: token)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(
            style: .destructive,
            title: R.string.localizable.hide()
        ) { [weak self] (action, _, completionHandler) in
            guard let self = self else {
                return
            }
            let token = self.tokens[indexPath.row]
            let alert = UIAlertController(title: R.string.localizable.wallet_hide_asset_confirmation(token.symbol), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.hide(), style: .default, handler: { (_) in
                self.hideToken(with: token.assetID)
            }))
            self.present(alert, animated: true, completion: nil)
            completionHandler(true)
        }
        action.backgroundColor = R.color.theme()
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
}

extension ClassicWalletViewController: TokenActionView.Delegate {
    
    func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction) {
        switch action {
        case .send:
            let selector = Web3TokenSelectorViewController(walletID: walletID, tokens: tokens)
            selector.onSelected = { [walletID] token in
                guard let chain = Web3Chain.chain(chainID: token.chainID) else {
                    return
                }
                guard let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: chain.chainID) else {
                    return
                }
                let payment = Web3SendingTokenPayment(chain: chain, token: token, fromAddress: address.destination)
                let selector = Web3TokenReceiverViewController(payment: payment)
                self.navigationController?.pushViewController(selector, animated: true)
            }
            present(selector, animated: true, completion: nil)
        case .receive:
            let selector = Web3TokenSelectorViewController(walletID: walletID, tokens: tokens)
            selector.onSelected = { token in
                let selector = Web3ReceiveSourceViewController(token: token)
                self.navigationController?.pushViewController(selector, animated: true)
            }
            withMnemonicsBackupChecked {
                self.present(selector, animated: true, completion: nil)
            }
        case .swap:
            break
        }
    }
    
}

extension ClassicWalletViewController: WalletSearchViewControllerDelegate {
    
    func walletSearchViewController(_ controller: WalletSearchViewController, didSelectToken token: MixinTokenItem) {
        let amount = Web3TokenDAO.shared.amount(walletID: walletID, assetID: token.assetID)
        let isHidden = Web3TokenExtraDAO.shared.isHidden(walletID: walletID, assetID: token.assetID)
        let web3Token = Web3Token(
            walletID: walletID,
            assetID: token.assetID,
            chainID: token.chainID,
            assetKey: token.assetKey,
            kernelAssetID: token.kernelAssetID,
            symbol: token.symbol,
            name: token.name,
            precision: 0,
            iconURL: token.iconURL,
            amount: amount ?? "0",
            usdPrice: token.usdPrice,
            usdChange: token.usdChange
        )
        let item = Web3TokenItem(token: web3Token, hidden: isHidden, chain: token.chain)
        let controller = Web3TokenViewController(token: item)
        navigationController?.pushViewController(controller, animated: true)
        if amount == nil,
           let address = Web3AddressDAO.shared.address(walletID: walletID, chainID: token.chainID)
        {
            RouteAPI.asset(
                assetID: token.assetID,
                address: address.destination,
                queue: .global()
            ) { result in
                switch result {
                case .success(let token):
                    Web3TokenDAO.shared.save(tokens: [token])
                case .failure(let error):
                    Logger.general.debug(category: "ClassicWallet", message: "\(error)")
                }
            }
        }
    }
    
}
