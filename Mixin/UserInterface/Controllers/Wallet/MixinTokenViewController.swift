import UIKit
import MixinServices

final class MixinTokenViewController: TokenViewController<MixinTokenItem, SafeSnapshotItem> {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = NavigationTitleView(
            title: token.name,
            subtitle: token.depositNetworkName
        )
        tableView.register(R.nib.snapshotCell)
        tableView.reloadData()
        
        let center: NotificationCenter = .default
        center.addObserver(self, selector: #selector(balanceDidUpdate(_:)), name: UTXOService.balanceDidUpdateNotification, object: nil)
        center.addObserver(self, selector: #selector(assetsDidChange(_:)), name: TokenDAO.tokensDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(chainsDidChange(_:)), name: ChainDAO.chainsDidChangeNotification, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshTokenJob(assetID: token.assetID))
        
        center.addObserver(self, selector: #selector(snapshotsDidSave(_:)), name: SafeSnapshotDAO.snapshotDidSaveNotification, object: nil)
        center.addObserver(self, selector: #selector(inscriptionDidRefresh(_:)), name: RefreshInscriptionJob.didFinishNotification, object: nil)
        reloadSnapshots()
    }
    
    override func send() {
        let receiver = MixinTokenReceiverViewController(token: token)
        navigationController?.pushViewController(receiver, animated: true)
    }
    
    override func setTokenHidden(_ hidden: Bool) {
        let extra = TokenExtra(
            assetID: token.assetID,
            kernelAssetID: token.kernelAssetID,
            isHidden: hidden,
            balance: token.balance,
            updatedAt: Date().toUTCString()
        )
        DispatchQueue.global().async {
            TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
        }
    }
    
    override func updateBalanceCell(_ cell: TokenBalanceCell) {
        cell.reloadData(token: token)
        cell.actionView.delegate = self
        cell.delegate = self
    }
    
    override func tableView(_ tableView: UITableView, cellForTransaction transaction: SafeSnapshotItem) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot.identifier) as! SnapshotCell
        cell.render(snapshot: transaction)
        cell.delegate = self
        return cell
    }
    
    override func viewMarket() {
        let market = MarketViewController(token: token, chartPoints: chartPoints)
        market.pushingViewController = self
        navigationController?.pushViewController(market, animated: true)
    }
    
    override func view(transaction: SafeSnapshotItem) {
        let inscriptionItem: InscriptionItem? = if let hash = transaction.inscriptionHash {
            InscriptionDAO.shared.inscriptionItem(with: hash)
        } else {
            nil
        }
        let viewController = SafeSnapshotViewController(
            token: token,
            snapshot: transaction,
            messageID: nil,
            inscription: inscriptionItem
        )
        navigationController?.pushViewController(viewController, animated: true)
        reporter.report(event: .transactionDetail, tags: ["source": "asset_detail"])
    }
    
    override func viewAllTransactions() {
        let history = MixinTransactionHistoryViewController(token: token)
        navigationController?.pushViewController(history, animated: true)
        reporter.report(event: .allTransactions, tags: ["source": "asset_detail"])
    }
    
    @objc private func balanceDidUpdate(_ notification: Notification) {
        guard let id = notification.userInfo?[UTXOService.assetIDUserInfoKey] as? String else {
            return
        }
        guard id == token.assetID else {
            return
        }
        reloadToken()
    }
    
    @objc private func assetsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[TokenDAO.UserInfoKey.assetId] as? String else {
            return
        }
        guard id == token.assetID else {
            return
        }
        reloadToken()
    }
    
    @objc private func chainsDidChange(_ notification: Notification) {
        guard let id = notification.userInfo?[ChainDAO.UserInfoKey.chainId] as? String else {
            return
        }
        guard id == token.chainID else {
            return
        }
        reloadToken()
    }
    
    @objc private func snapshotsDidSave(_ notification: Notification) {
        guard let snapshots = notification.userInfo?[SafeSnapshotDAO.snapshotsUserInfoKey] as? [SafeSnapshot] else {
            return
        }
        guard snapshots.contains(where: { $0.assetID == token.assetID }) else {
            return
        }
        reloadSnapshots()
    }
    
    @objc private func inscriptionDidRefresh(_ notification: Notification) {
        // Not the best approach, but since inscriptions don’t refresh frequently, simply reload it.
        reloadSnapshots()
    }
    
    private func reloadToken() {
        let assetID = token.assetID
        DispatchQueue.global().async { [weak self] in
            guard let token = TokenDAO.shared.tokenItem(assetID: assetID) else {
                return
            }
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.token = token
                let indexPath = IndexPath(row: 0, section: Section.balance.rawValue)
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.tableView.endUpdates()
            }
        }
    }
    
    private func reloadSnapshots() {
        queue.async { [limit=transactionsCount, assetID=token.assetID, weak self] in
            let dao: SafeSnapshotDAO = .shared
            
            let pendingSnapshots = dao.snapshots(assetID: assetID, pending: true, limit: nil)
            
            let limitExceededTransactionSnapshots = dao.snapshots(assetID: assetID, pending: false, limit: limit + 1)
            let hasMoreSnapshots = limitExceededTransactionSnapshots.count > limit
            let transactionSnapshots = Array(limitExceededTransactionSnapshots.prefix(limit))
            let transactionRows = TransactionRow.rows(
                transactions: transactionSnapshots,
                hasMore: hasMoreSnapshots
            )
            
            DispatchQueue.main.async {
                self?.reloadTransactions(pending: pendingSnapshots, finished: transactionRows)
            }
        }
    }
    
}

extension MixinTokenViewController: TokenBalanceCellDelegate {
    
    func tokenBalanceCellWantsToRevealOutputs(_ cell: TokenBalanceCell) {
        let outputs = OutputsViewController(token: token)
        navigationController?.pushViewController(outputs, animated: true)
    }
    
}

extension MixinTokenViewController: TokenActionView.Delegate {
    
    func tokenActionView(_ view: TokenActionView, wantsToPerformAction action: TokenAction) {
        switch action {
        case .receive:
            let deposit = DepositViewController(token: token)
            withMnemonicsBackupChecked {
                self.navigationController?.pushViewController(deposit, animated: true)
            }
        case .send:
            send()
        case .swap:
            let swap = MixinTradeViewController(
                mode: .simple,
                sendAssetID: token.assetID,
                receiveAssetID: AssetID.erc20USDT,
                referral: nil
            )
            navigationController?.pushViewController(swap, animated: true)
            reporter.report(event: .tradeStart, tags: ["wallet": "main", "source": "asset_detail"])
        case .buy:
            break
        }
    }
    
}

extension MixinTokenViewController: SnapshotCellDelegate {
    
    func walletSnapshotCellDidSelectIcon(_ cell: SnapshotCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            case let .transaction(snapshot) = transactionRows[indexPath.row],
            let userId = snapshot.opponentUserID
        else {
            return
        }
        DispatchQueue.global().async {
            guard let user = UserDAO.shared.getUser(userId: userId) else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                let vc = UserProfileViewController(user: user)
                self?.present(vc, animated: true, completion: nil)
            }
        }
    }
    
}
