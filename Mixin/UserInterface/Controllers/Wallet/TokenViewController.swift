import UIKit
import MixinServices

final class TokenViewController: UIViewController, MnemonicsBackupChecking {
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.TokenViewController")
    private let transactionsCount = 20
    
    private weak var tableView: UITableView!
    
    private(set) var token: TokenItem
    
    private var performSendOnAppear: Bool
    private var pendingSnapshots: [SafeSnapshotItem] = []
    private var transactionRows: [TransactionRow] = []
    private var market: MarketResult
    private var chartPoints: [ChartView.Point]?
    
    init(
        token: TokenItem,
        market: Market? = nil,
        performSendOnAppear: Bool = false
    ) {
        self.token = token
        self.market = if let market {
            .some(market)
        } else {
            .unknown
        }
        self.performSendOnAppear = performSendOnAppear
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = token.name
        navigationItem.titleView = NavigationTitleView(
            title: token.name,
            subtitle: token.depositNetworkName
        )
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_more(),
            target: self,
            action: #selector(showMoreActions(_:))
        )
        
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
        center.addObserver(self, selector: #selector(inscriptionDidRefresh(_:)), name: RefreshInscriptionJob.didFinishNotification, object: nil)
        reloadSnapshots()
        
        center.addObserver(self, selector: #selector(reloadMarket(_:)), name: MarketDAO.didUpdateNotification, object: nil)
        
        DispatchQueue.global().async { [id=token.assetID, weak self] in
            if let market = MarketDAO.shared.market(assetID: id) {
                DispatchQueue.main.sync {
                    self?.reloadMarket(result: .some(market))
                }
            }
            if let storage = MarketDAO.shared.priceHistory(assetID: id, period: .day),
               let points = PriceHistory(storage: storage)?.chartViewPoints()
            {
                DispatchQueue.main.sync {
                    self?.reloadChart(points)
                }
            }
            self?.loadMarketsFromRemote(assetID: id)
            RouteAPI.priceHistory(id: id, period: .day, queue: .global()) { result in
                switch result {
                case .success(let price):
                    if let storage = price.asStorage() {
                        MarketDAO.shared.savePriceHistory(storage)
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
    
    @objc private func showMoreActions(_ sender: Any) {
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
    
    @objc private func reloadMarket(_ notification: Notification) {
        DispatchQueue.global().async { [id=token.assetID, weak self] in
            guard let market = MarketDAO.shared.market(assetID: id) else {
                return
            }
            DispatchQueue.main.async {
                self?.reloadMarket(result: .some(market))
            }
        }
    }
    
}

extension TokenViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
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
        case pending
        case transactions
    }
    
    private enum MarketRow: Int, CaseIterable {
        case title
        case content
    }
    
    private enum MarketResult {
        
        case unknown
        case invalid
        case some(Market)
        
        var value: Market? {
            switch self {
            case .some(let market):
                market
            default:
                nil
            }
        }
        
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
    
    private func reloadMarket(result: MarketResult) {
        self.market = result
        let indexPath = IndexPath(row: MarketRow.content.rawValue, section: Section.market.rawValue)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    private func reloadChart(_ points: [ChartView.Point]) {
        self.chartPoints = points
        let indexPath = IndexPath(row: MarketRow.content.rawValue, section: Section.market.rawValue)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
    private func loadMarketsFromRemote(assetID: String) {
        RouteAPI.markets(id: assetID, queue: .global()) { [weak self] result in
            switch result {
            case .success(let market):
                if let market = MarketDAO.shared.save(market: market) {
                    DispatchQueue.main.async {
                        self?.reloadMarket(result: .some(market))
                    }
                }
            case .failure(.response(.notFound)):
                DispatchQueue.main.async {
                    self?.reloadMarket(result: .invalid)
                }
            case .failure(let error):
                Logger.general.debug(category: "MarketView", message: "\(error)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.loadMarketsFromRemote(assetID: assetID)
                }
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
            let transactionRows: [TransactionRow] = if transactionSnapshots.isEmpty {
                [.title, .emptyIndicator]
            } else {
                if hasMoreSnapshots {
                    [.title] + transactionSnapshots.map({ .transaction($0) }) + [.viewAll, .bottomSeparator]
                } else {
                    [.title] + transactionSnapshots.map({ .transaction($0) }) + [.bottomSeparator]
                }
            }
            
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.pendingSnapshots = pendingSnapshots
                self.transactionRows = transactionRows
                UIView.performWithoutAnimation {
                    let sections = IndexSet([Section.transactions.rawValue, Section.pending.rawValue])
                    self.tableView.reloadSections(sections, with: .none)
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
                selector.onSelect = { [weak selector] (user) in
                    let transfer = TransferOutViewController(token: token, to: .contact(user))
                    var viewControllers = navigationController.viewControllers
                    if let index = viewControllers.lastIndex(where: { $0 == selector }) {
                        viewControllers.remove(at: index)
                    }
                    viewControllers.append(transfer)
                    navigationController.setViewControllers(viewControllers, animated: true)
                }
                navigationController.pushViewController(selector, animated: true)
            }
        }
        present(selector, animated: true, completion: nil)
    }
    
    private func view(snapshot: SafeSnapshotItem) {
        let inscriptionItem: InscriptionItem? = if let hash = snapshot.inscriptionHash {
            InscriptionDAO.shared.inscriptionItem(with: hash)
        } else {
            nil
        }
        let viewController = SafeSnapshotViewController(
            token: token,
            snapshot: snapshot,
            messageID: nil,
            inscription: inscriptionItem
        )
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension TokenViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .balance:
            1
        case .market:
            MarketRow.allCases.count
        case .pending:
            pendingSnapshots.isEmpty ? 0 : pendingSnapshots.count + 2 // Title and bottom separator
        case .transactions:
            transactionRows.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .balance:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.token_balance, for: indexPath)!
            cell.reloadData(token: token)
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
                if let market = market.value {
                    cell.priceLabel.text = market.localizedPrice
                } else {
                    cell.priceLabel.text = token.localizedFiatMoneyPrice
                }
                if let points = chartPoints, points.count >= 2 {
                    let firstValue = points[0].value
                    let lastValue = points[points.count - 1].value
                    let change = (lastValue - firstValue) / firstValue
                    cell.changeLabel.text = NumberFormatter.percentage.string(decimal: change)
                    cell.changeLabel.marketColor = .byValue(change)
                    cell.chartView.points = points
                } else {
                    if let market = market.value {
                        cell.changeLabel.text = market.localizedPriceChangePercentage7D
                        cell.changeLabel.marketColor = .byValue(market.decimalPriceChangePercentage7D)
                    } else {
                        cell.changeLabel.text = token.localizedUSDChange
                        cell.changeLabel.marketColor = .byValue(token.decimalUSDChange)
                    }
                    cell.chartView.points = []
                }
                return cell
            }
        case .pending:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.pending()
                cell.disclosureIndicatorView.isHidden = true
                return cell
            case pendingSnapshots.count + 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier.emptyCell, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
                cell.render(snapshot: pendingSnapshots[indexPath.row - 1])
                cell.delegate = self
                return cell
            }
        case .transactions:
            let row = transactionRows[indexPath.row]
            switch row {
            case .title:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.transactions()
                cell.disclosureIndicatorView.isHidden = false
                return cell
            case .emptyIndicator:
                return tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.no_transaction_indicator, for: indexPath)!
            case .transaction(let snapshot):
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.snapshot, for: indexPath)!
                cell.render(snapshot: snapshot)
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
            UITableView.automaticDimension
        case .pending:
            switch indexPath.row {
            case 0:
                UITableView.automaticDimension
            case pendingSnapshots.count + 1:
                10
            default:
                62
            }
        case .transactions:
            switch transactionRows[indexPath.row] {
            case .title, .emptyIndicator:
                UITableView.automaticDimension
            case .transaction:
                62
            case .bottomSeparator:
                10
            case .viewAll:
                UITableView.automaticDimension
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .pending where pendingSnapshots.isEmpty:
                .leastNormalMagnitude
        default:
            10
        }
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
            let market = MarketViewController(token: token, chartPoints: chartPoints)
            market.pushingViewController = self
            navigationController?.pushViewController(market, animated: true)
        case .pending:
            switch indexPath.row {
            case 0, pendingSnapshots.count + 1:
                break
            default:
                let snapshot = pendingSnapshots[indexPath.row - 1]
                view(snapshot: snapshot)
            }
        case .transactions:
            let row = transactionRows[indexPath.row]
            switch row {
            case .title, .viewAll:
                let history = TransactionHistoryViewController(token: token)
                navigationController?.pushViewController(history, animated: true)
            case .transaction(let snapshot):
                view(snapshot: snapshot)
            case .emptyIndicator, .bottomSeparator:
                break
            }
        }
    }
    
}

extension TokenViewController: TokenActionView.Delegate {
    
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
            let swap = MixinSwapViewController(sendAssetID: token.assetID, receiveAssetID: AssetID.erc20USDT)
            navigationController?.pushViewController(swap, animated: true)
            reporter.report(event: .swapStart, tags: ["entrance": "wallet", "source": "mixin"])
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
        navigationController?.pushViewController(outputs, animated: true)
    }
    
}
