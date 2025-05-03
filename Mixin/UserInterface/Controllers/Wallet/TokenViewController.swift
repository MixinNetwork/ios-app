import UIKit
import MixinServices

class TokenViewController<Token: HideableToken & ValuableToken, Transaction>: UIViewController, UITableViewDataSource, UITableViewDelegate, MnemonicsBackupChecking {
    
    let queue = DispatchQueue(label: "one.mixin.messenger.TokenViewController")
    let transactionsCount = 20
    
    var token: Token
    
    weak var tableView: UITableView!
    
    private(set) var pendingSnapshots: [Transaction] = []
    private(set) var transactionRows: [TransactionRow] = []
    private(set) var market: MarketResult
    private(set) var chartPoints: [ChartView.Point]?
    
    private let headerReuseIdentifier = "h"
    private let emptyCellReuseIdentifier = "e"
    
    private var performSendOnAppear: Bool
    
    init(
        token: Token,
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
        tableView.register(R.nib.noTransactionIndicatorCell)
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: emptyCellReuseIdentifier
        )
        tableView.register(
            UITableViewHeaderFooterView.self,
            forHeaderFooterViewReuseIdentifier: headerReuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadMarket(_:)),
            name: MarketDAO.didUpdateNotification,
            object: nil
        )
        
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
    
    func reloadTransactions(pending: [Transaction], finished: [TransactionRow]) {
        self.pendingSnapshots = pending
        self.transactionRows = finished
        UIView.performWithoutAnimation {
            let sections = IndexSet([Section.transactions.rawValue, Section.pending.rawValue])
            self.tableView.reloadSections(sections, with: .none)
        }
    }
    
    func send() {
        
    }
    
    func setTokenHidden(_ hidden: Bool) {
        
    }
    
    func viewMarket() {
        
    }
    
    func view(transaction: Transaction) {
        
    }
    
    func viewAllTransactions() {
        
    }
    
    func updateBalanceCell(_ cell: TokenBalanceCell) {
        
    }
    
    func tableView(_ tableView: UITableView, cellForTransaction transaction: Transaction) -> UITableViewCell {
        fatalError("Must override")
    }
    
    // MARK: - UITableViewDataSource
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
            updateBalanceCell(cell)
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
                    } else if let token = token as? ChangeReportingToken {
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
                let cell = tableView.dequeueReusableCell(withIdentifier: emptyCellReuseIdentifier, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            default:
                let transaction = pendingSnapshots[indexPath.row - 1]
                return self.tableView(tableView, cellForTransaction: transaction)
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
                return self.tableView(tableView, cellForTransaction: snapshot)
            case .bottomSeparator:
                let cell = tableView.dequeueReusableCell(withIdentifier: emptyCellReuseIdentifier, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            case .viewAll:
                let cell = tableView.dequeueReusableCell(withIdentifier: emptyCellReuseIdentifier, for: indexPath)
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
    
    // MARK: - UITableViewDelegate
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
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseIdentifier)!
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
            viewMarket()
        case .pending:
            switch indexPath.row {
            case 0, pendingSnapshots.count + 1:
                break
            default:
                let snapshot = pendingSnapshots[indexPath.row - 1]
                view(transaction: snapshot)
            }
        case .transactions:
            let row = transactionRows[indexPath.row]
            switch row {
            case .title, .viewAll:
                viewAllTransactions()
            case .transaction(let snapshot):
                view(transaction: snapshot)
            case .emptyIndicator, .bottomSeparator:
                break
            }
        }
    }
    
    @objc private func showMoreActions(_ sender: Any) {
        let token = self.token
        let wasHidden = token.isHidden
        let title = wasHidden ? R.string.localizable.show_asset() : R.string.localizable.hide_asset()
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
            self.setTokenHidden(!wasHidden)
            self.navigationController?.popViewController(animated: true)
        }))
        sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        present(sheet, animated: true, completion: nil)
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
    
    enum Section: Int, CaseIterable {
        case balance
        case market
        case pending
        case transactions
    }
    
    enum MarketRow: Int, CaseIterable {
        case title
        case content
    }
    
    enum MarketResult {
        
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
    
    enum TransactionRow {
        
        case title
        case emptyIndicator
        case transaction(Transaction)
        case bottomSeparator
        case viewAll
        
        static func rows(transactions: [Transaction], hasMore: Bool) -> [TransactionRow] {
            if transactions.isEmpty {
                [.title, .emptyIndicator]
            } else {
                if hasMore {
                    [.title] + transactions.map({ .transaction($0) }) + [.viewAll, .bottomSeparator]
                } else {
                    [.title] + transactions.map({ .transaction($0) }) + [.bottomSeparator]
                }
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
    
}
