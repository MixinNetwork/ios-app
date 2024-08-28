import UIKit
import MixinServices

final class TokenViewController: UIViewController {
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.TokenViewController")
    private let transactionsCount = 20
    
    private weak var tableView: UITableView!
    
    private(set) var token: TokenItem
    
    private var performSendOnAppear: Bool
    private var transactionRows: [TransactionRow] = []
    private var chartPoints: [ChartView.Point]?
    
    private init(token: TokenItem, performSendOnAppear: Bool = false) {
        self.token = token
        self.performSendOnAppear = performSendOnAppear
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static func contained(token: TokenItem, performSendOnAppear: Bool = false) -> ContainerViewController {
        let controller = TokenViewController(token: token, performSendOnAppear: performSendOnAppear)
        return ContainerViewController.instance(viewController: controller, title: token.name)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let container {
            container.setSubtitle(subtitle: token.depositNetworkName)
            container.view.backgroundColor = R.color.background_secondary()
            container.navigationBar.backgroundColor = R.color.background_secondary()
        }
        
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 62
        tableView.separatorStyle = .none
        tableView.register(R.nib.tokenBalanceCell)
        tableView.register(R.nib.insetGroupedTitleCell)
        tableView.register(R.nib.tokenMarketCell)
        tableView.register(R.nib.snapshotCell)
        tableView.register(R.nib.noTransactionIndicatorCell)
        tableView.register(UITableViewCell.self,
                           forCellReuseIdentifier: ReuseIdentifier.emptyCell)
        tableView.register(UITableViewHeaderFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseIdentifier.header)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        
        let center: NotificationCenter = .default
        center.addObserver(self, selector: #selector(balanceDidUpdate(_:)), name: UTXOService.balanceDidUpdateNotification, object: nil)
        center.addObserver(self, selector: #selector(assetsDidChange(_:)), name: TokenDAO.tokensDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(chainsDidChange(_:)), name: ChainDAO.chainsDidChangeNotification, object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshTokenJob(assetID: token.assetID))
        
        center.addObserver(self, selector: #selector(snapshotsDidSave(_:)), name: SafeSnapshotDAO.snapshotDidSaveNotification, object: nil)
        center.addObserver(self, selector: #selector(inscriptionDidRefresh(_:)), name: RefreshInscriptionJob.didFinishedNotification, object: nil)
        reloadSnapshots()
        
        DispatchQueue.global().async { [id=token.assetID, weak self] in
            if let history = MarketDAO.shared.priceHistory(assetID: id, period: .day),
               let prices = TokenPrice(priceHistory: history)?.chartViewPoints()
            {
                DispatchQueue.main.sync {
                    self?.reloadChart(prices)
                }
            }
            RouteAPI.priceHistory(assetID: id, period: .day, queue: .global()) { result in
                switch result {
                case .success(let price):
                    if let history = price.asPriceHistory() {
                        MarketDAO.shared.savePriceHistory(history)
                    }
                    let prices = price.chartViewPoints()
                    DispatchQueue.main.async {
                        self?.reloadChart(prices)
                    }
                case .failure(let error):
                    Logger.general.debug(category: "TokenView", message: "\(error)")
                }
            }
        }
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if performSendOnAppear {
            performSendOnAppear = false
            send()
        }
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
    
}

extension TokenViewController {
    
    private enum ReuseIdentifier {
        static let header = "header"
        static let emptyCell = "emtpy_cell"
    }
    
    private enum Section: Int, CaseIterable {
        case balance
        case market
        case transactions
    }
    
    private enum MarketRow: Int, CaseIterable {
        case title
        case content
    }
    
    private enum TransactionRow {
        
        case title
        case emptyIndicator
        case transaction(SafeSnapshotItem)
        case bottomSeparator
        case viewAll
        
        init(snapshots: [SafeSnapshotItem], hasMoreSnapshots: Bool, row: Int) {
            if snapshots.isEmpty {
                switch row {
                case 0:
                    self = .title
                default:
                    self = .emptyIndicator
                }
            } else {
                switch row {
                case 0:
                    self = .title
                case snapshots.count + 1:
                    if hasMoreSnapshots {
                        self = .viewAll
                    } else {
                        self = .bottomSeparator
                    }
                case snapshots.count + 2:
                    self = .bottomSeparator
                default:
                    self = .transaction(snapshots[row - 1])
                }
            }
        }
        
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
    
    private func reloadChart(_ points: [ChartView.Point]) {
        self.chartPoints = points
        let indexPath = IndexPath(row: MarketRow.content.rawValue, section: Section.market.rawValue)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    private func reloadSnapshots() {
        var filter = SafeSnapshot.Filter()
        filter.tokens = [token]
        queue.async { [limit=transactionsCount, weak self] in
            let limitExceededSnapshots = SafeSnapshotDAO.shared.snapshots(filter: filter, order: .newest, limit: limit + 1)
            let hasMoreSnapshots = limitExceededSnapshots.count > limit
            let snapshots = Array(limitExceededSnapshots.prefix(limit))
            let transactionRows: [TransactionRow] = if snapshots.isEmpty {
                [.title, .emptyIndicator]
            } else {
                if hasMoreSnapshots {
                    [.title] + snapshots.map({ .transaction($0) }) + [.viewAll, .bottomSeparator]
                } else {
                    [.title] + snapshots.map({ .transaction($0) }) + [.bottomSeparator]
                }
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                let hadTransactionSection = !self.transactionRows.isEmpty
                self.transactionRows = transactionRows
                let sections = IndexSet(integer: Section.transactions.rawValue)
                UIView.performWithoutAnimation {
                    if hadTransactionSection {
                        self.tableView.reloadSections(sections, with: .none)
                    } else {
                        self.tableView.insertSections(sections, with: .none)
                    }
                }
            }
        }
    }
    
    private func send() {
        guard let navigationController else {
            return
        }
        let token = self.token
        let selector = SendingDestinationSelectorViewController(destinations: [.address, .contact]) { destination in
            switch destination {
            case .address:
                let address = AddressViewController.instance(token: token)
                navigationController.pushViewController(address, animated: true)
            case .contact:
                let selector = TransferReceiverViewController()
                let container = ContainerViewController.instance(viewController: selector, title: R.string.localizable.send_to_title())
                selector.onSelect = { (user) in
                    let transfer = TransferOutViewController.instance(token: token, to: .contact(user))
                    var viewControllers = navigationController.viewControllers
                    if let index = viewControllers.lastIndex(where: { $0 == container }) {
                        viewControllers.remove(at: index)
                    }
                    viewControllers.append(transfer)
                    navigationController.setViewControllers(viewControllers, animated: true)
                }
                navigationController.pushViewController(container, animated: true)
            }
        }
        present(selector, animated: true, completion: nil)
    }
    
}

extension TokenViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let token = self.token
        let wasHidden = token.isHidden
        let title = wasHidden ? R.string.localizable.show_asset() : R.string.localizable.hide_asset()
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
            DispatchQueue.global().async {
                let extra = TokenExtra(assetID: token.assetID,
                                       kernelAssetID: token.kernelAssetID,
                                       isHidden: !wasHidden,
                                       balance: token.balance,
                                       updatedAt: Date().toUTCString())
                TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
            }
            self.navigationController?.popViewController(animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_title_more()
    }
    
}

extension TokenViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        var count = Section.allCases.count
        if transactionRows.isEmpty {
            count -= 1
        }
        return count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .balance:
            1
        case .market:
            MarketRow.allCases.count
        case .transactions:
            transactionRows.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .balance:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_balance, for: indexPath)!
            cell.reloadData(token: token)
            cell.actionView.actions = [.send, .receive, .swap]
            cell.actionView.delegate = self
            cell.delegate = self
            return cell
        case .market:
            switch MarketRow(rawValue: indexPath.row)! {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.market()
                return cell
            case .content:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_market, for: indexPath)!
                cell.reloadData(token: token, points: chartPoints)
                return cell
            }
        case .transactions:
            let row = transactionRows[indexPath.row]
            switch row {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.transactions()
                return cell
            case .emptyIndicator:
                return tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.no_transaction_indicator, for: indexPath)!
            case .transaction(let snapshot):
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
                cell.render(snapshot: snapshot, token: token)
                cell.delegate = self
                return cell
            case .bottomSeparator:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.emptyCell, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            case .viewAll:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.emptyCell, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = {
                    var content = cell.defaultContentConfiguration()
                    content.text = R.string.localizable.view_all()
                    content.textProperties.alignment = .center
                    content.textProperties.font = .scaledFont(ofSize: 14, weight: .regular)
                    content.textProperties.color = R.color.theme()!
                    return content
                }()
                return cell
            }
        }
    }
    
}

extension TokenViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .balance, .market:
            return UITableView.automaticDimension
        case .transactions:
            let row = transactionRows[indexPath.row]
            switch row {
            case .title, .emptyIndicator:
                return UITableView.automaticDimension
            case .transaction:
                return 62
            case .bottomSeparator:
                return 10
            case .viewAll:
                return UITableView.automaticDimension
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        10
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseIdentifier.header)!
        view.contentView.backgroundColor = R.color.background_secondary()
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .balance:
            break
        case .market:
            let market = TokenMarketViewController.contained(
                token: token,
                chartPoints: chartPoints,
                pushingViewController: self
            )
            navigationController?.pushViewController(market, animated: true)
        case .transactions:
            let row = transactionRows[indexPath.row]
            switch row {
            case .title, .viewAll:
                let history = TransactionHistoryViewController.contained(token: token)
                navigationController?.pushViewController(history, animated: true)
            case .transaction(let snapshot):
                let inscriptionItem: InscriptionItem? = if let hash = snapshot.inscriptionHash {
                    InscriptionDAO.shared.inscriptionItem(with: hash)
                } else {
                    nil
                }
                let viewController = SafeSnapshotViewController.instance(
                    token: token,
                    snapshot: snapshot,
                    messageID: nil,
                    inscription: inscriptionItem
                )
                navigationController?.pushViewController(viewController, animated: true)
            case .emptyIndicator, .bottomSeparator:
                break
            }
        }
    }
    
}

extension TokenViewController: TransferActionViewDelegate {
    
    func transferActionView(_ view: TransferActionView, didSelect action: TransferActionView.Action) {
        switch action {
        case .send:
            send()
        case .receive:
            let deposit = DepositViewController.instance(token: token)
            navigationController?.pushViewController(deposit, animated: true)
        case .swap:
            let swap = MixinSwapViewController.contained(sendAssetID: token.assetID, receiveAssetID: nil)
            navigationController?.pushViewController(swap, animated: true)
        }
    }
    
}

extension TokenViewController: SnapshotCellDelegate {
    
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

extension TokenViewController: TokenBalanceCellDelegate {
    
    func tokenBalanceCellWantsToRevealOutputs(_ cell: TokenBalanceCell) {
        let outputs = OutputsViewController(token: token)
        let container = ContainerViewController.instance(viewController: outputs, title: "Outputs")
        navigationController?.pushViewController(container, animated: true)
    }
    
}
