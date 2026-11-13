import UIKit
import MixinServices

class TokenViewController<Token: HideableToken & ValuableToken & MaliciousDistinguishable, Transaction>: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, AssetChangeAccountRecoveryChecking {
    
    let queue = DispatchQueue(label: "one.mixin.messenger.TokenViewController")
    let transactionsCount = 20
    
    var token: Token
    var earning: TokenEarningViewModel?
    
    weak var collectionView: UICollectionView!
    
    private(set) var pendingSnapshots: [Transaction] = []
    private(set) var market: MarketResult
    private(set) var chartPoints: [ChartView.Point]?
    
    private let maliciousWarningReuseIdentifier = "m"
    private let titleReuseIdentifier = "t"
    private let viewAllReuseIdentifier = "v"
    private let dateHeaderReuseIdentifier = "d"
    
    private var transactionSections: [TransactionSection] = []
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
        
        title = token.symbol
        navigationItem.rightBarButtonItem = .tintedIcon(
            image: R.image.ic_title_more(),
            target: self,
            action: #selector(showMoreActions(_:))
        )
        
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else {
                return nil
            }
            switch Section(collectionViewIndex: sectionIndex) {
            case .warning:
                let size = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(62),
                )
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let horizontalInset: CGFloat = 20
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: self.token.isMalicious ? 10 : 0,
                    leading: horizontalInset,
                    bottom: 0,
                    trailing: horizontalInset,
                )
                return layoutSection
            case .balance:
                let size = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(62),
                )
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let horizontalInset: CGFloat = 20
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: 10,
                    leading: horizontalInset,
                    bottom: 0,
                    trailing: horizontalInset,
                )
                let background = NSCollectionLayoutDecorationItem.background(
                    elementKind: SectionBackgroundView.CornerRadius.small.rawValue
                )
                background.contentInsets = NSDirectionalEdgeInsets(
                    top: 10,
                    leading: horizontalInset,
                    bottom: 0,
                    trailing: horizontalInset,
                )
                layoutSection.decorationItems = [background]
                return layoutSection
            case .market:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(62),
                )
                let title = NSCollectionLayoutItem(layoutSize: itemSize)
                let market = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(124),
                    ),
                    subitems: [title, market],
                )
                let horizontalInset: CGFloat = 20
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: 10,
                    leading: horizontalInset,
                    bottom: 0,
                    trailing: horizontalInset,
                )
                let background = NSCollectionLayoutDecorationItem.background(
                    elementKind: SectionBackgroundView.CornerRadius.small.rawValue
                )
                background.contentInsets = NSDirectionalEdgeInsets(
                    top: 10,
                    leading: horizontalInset,
                    bottom: 0,
                    trailing: horizontalInset,
                )
                layoutSection.decorationItems = [background]
                return layoutSection
            case .earning:
                let size = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(62),
                )
                let item = NSCollectionLayoutItem(layoutSize: size)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
                let horizontalInset: CGFloat = 20
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: self.earning == nil ? 0 : 10,
                    leading: horizontalInset,
                    bottom: 0,
                    trailing: horizontalInset,
                )
                if self.earning != nil {
                    let background = NSCollectionLayoutDecorationItem.background(
                        elementKind: SectionBackgroundView.CornerRadius.small.rawValue
                    )
                    background.contentInsets = NSDirectionalEdgeInsets(
                        top: 10,
                        leading: horizontalInset,
                        bottom: 0,
                        trailing: horizontalInset,
                    )
                    layoutSection.decorationItems = [background]
                }
                return layoutSection
            case .pending:
                let title = NSCollectionLayoutItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(62),
                    )
                )
                let transactions = self.pendingSnapshots.map { _ in
                    let item = NSCollectionLayoutItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .absolute(62),
                        )
                    )
                    item.contentInsets = NSDirectionalEdgeInsets(
                        top: 0,
                        leading: 3,
                        bottom: 0,
                        trailing: 4,
                    )
                    return item
                }
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(CGFloat(transactions.count + 1) * 62),
                    ),
                    subitems: [title] + transactions,
                )
                let horizontalInset: CGFloat = 20
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: self.pendingSnapshots.isEmpty ? 0 : 10,
                    leading: horizontalInset,
                    bottom: self.pendingSnapshots.isEmpty ? 0 : 10,
                    trailing: horizontalInset,
                )
                if !self.pendingSnapshots.isEmpty {
                    let background = NSCollectionLayoutDecorationItem.background(
                        elementKind: SectionBackgroundView.CornerRadius.small.rawValue
                    )
                    background.contentInsets = NSDirectionalEdgeInsets(
                        top: 10,
                        leading: horizontalInset,
                        bottom: 0,
                        trailing: horizontalInset,
                    )
                    layoutSection.decorationItems = [background]
                }
                return layoutSection
            case .transactions:
                let transactionSection = self.transactionSections[sectionIndex - Section.transactions.rawValue]
                let isFirstSection = sectionIndex == Section.transactions.rawValue
                let isLastSection = sectionIndex == Section.transactions.rawValue + self.transactionSections.count - 1
                let rows = transactionSection.rows
                var items = rows.map { row in
                    switch row {
                    case .title, .emptyIndicator, .viewAll:
                        return NSCollectionLayoutItem(
                            layoutSize: NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .estimated(62),
                            )
                        )
                    case .transaction:
                        let item = NSCollectionLayoutItem(
                            layoutSize: NSCollectionLayoutSize(
                                widthDimension: .fractionalWidth(1),
                                heightDimension: .absolute(62),
                            )
                        )
                        item.contentInsets = NSDirectionalEdgeInsets(
                            top: 0,
                            leading: 3,
                            bottom: 0,
                            trailing: 4,
                        )
                        return item
                    }
                }
                if items.isEmpty {
                    items = [NSCollectionLayoutItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .estimated(62),
                        )
                    )]
                }
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(CGFloat(items.count) * 62),
                    ),
                    subitems: items,
                )
                let hasTransactions = rows.contains { row in
                    switch row {
                    case .transaction: true
                    default: false
                    }
                }
                let horizontalInset: CGFloat = 20
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: isFirstSection && !rows.isEmpty ? 10 : 0,
                    leading: horizontalInset,
                    bottom: isLastSection && hasTransactions ? 10 : 0,
                    trailing: horizontalInset,
                )
                if transactionSection.date != nil {
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .fractionalWidth(1),
                            heightDimension: .estimated(44),
                        ),
                        elementKind: UICollectionView.elementKindSectionHeader,
                        alignment: .top,
                    )
                    header.pinToVisibleBounds = true
                    layoutSection.boundarySupplementaryItems = [header]
                }
                if !rows.isEmpty {
                    let cornerRadius: SectionBackgroundView.CornerRadius = switch (isFirstSection, isLastSection) {
                    case (true, true): .small
                    case (true, false): .smallTop
                    case (false, true): .smallBottom
                    case (false, false): .none
                    }
                    let background = NSCollectionLayoutDecorationItem.background(
                        elementKind: cornerRadius.rawValue
                    )
                    background.contentInsets = NSDirectionalEdgeInsets(
                        top: isFirstSection ? 10 : 0,
                        leading: horizontalInset,
                        bottom: 0,
                        trailing: horizontalInset,
                    )
                    layoutSection.decorationItems = [background]
                }
                return layoutSection
            }
        }
        for cornerRadius in [SectionBackgroundView.CornerRadius.small, .smallTop, .smallBottom, .none] {
            layout.register(
                SectionBackgroundView.self,
                forDecorationViewOfKind: cornerRadius.rawValue,
            )
        }
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        collectionView.alwaysBounceVertical = true
        collectionView.register(
            MaliciousTokenWarningCollectionViewCell.self,
            forCellWithReuseIdentifier: maliciousWarningReuseIdentifier,
        )
        collectionView.register(
            TokenTransactionDateHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: dateHeaderReuseIdentifier,
        )
        collectionView.register(R.nib.tokenBalanceCell)
        collectionView.register(R.nib.tokenMarketCell)
        collectionView.register(R.nib.tokenEarningCell)
        collectionView.register(R.nib.noTransactionIndicatorCell)
        collectionView.register(R.nib.transactionCell)
        collectionView.register(
            TokenSectionTitleCell.self,
            forCellWithReuseIdentifier: titleReuseIdentifier,
        )
        collectionView.register(
            UICollectionViewListCell.self,
            forCellWithReuseIdentifier: viewAllReuseIdentifier,
        )
        view.addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        self.collectionView = collectionView
        collectionView.dataSource = self
        collectionView.delegate = self
        
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
            collectionView.contentInset.bottom = 10
        } else {
            collectionView.contentInset.bottom = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if performSendOnAppear {
            performSendOnAppear = false
            send()
        }
    }
    
    func reloadTransactions(pending: [Transaction], finished: [TransactionSection]) {
        self.pendingSnapshots = pending
        self.transactionSections = finished
        UIView.performWithoutAnimation {
            self.collectionView.reloadData()
        }
    }
    
    func transactionRow(at indexPath: IndexPath) -> TransactionRow? {
        let sectionIndex = indexPath.section - Section.transactions.rawValue
        guard transactionSections.indices.contains(sectionIndex) else {
            return nil
        }
        let rows = transactionSections[sectionIndex].rows
        guard rows.indices.contains(indexPath.item) else {
            return nil
        }
        return rows[indexPath.item]
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
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForTransaction transaction: Transaction,
        at indexPath: IndexPath,
    ) -> UICollectionViewCell {
        fatalError("Must override")
    }
    
    // MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.transactions.rawValue + transactionSections.count
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int,
    ) -> Int {
        switch Section(collectionViewIndex: section) {
        case .warning:
            token.isMalicious ? 1 : 0
        case .balance:
            1
        case .market:
            MarketRow.allCases.count
        case .earning:
            earning == nil ? 0 : 1
        case .pending:
            pendingSnapshots.isEmpty ? 0 : pendingSnapshots.count + 1 // Title
        case .transactions:
            transactionSections[section - Section.transactions.rawValue].rows.count
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath,
    ) -> UICollectionViewCell {
        switch Section(collectionViewIndex: indexPath.section) {
        case .warning:
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: maliciousWarningReuseIdentifier,
                for: indexPath,
            )
        case .balance:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: R.reuseIdentifier.token_balance,
                for: indexPath,
            )!
            updateBalanceCell(cell)
            return cell
        case .market:
            switch MarketRow(rawValue: indexPath.item)! {
            case .title:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: titleReuseIdentifier,
                    for: indexPath,
                ) as! TokenSectionTitleCell
                cell.label.text = R.string.localizable.market()
                cell.disclosureIndicatorView.isHidden = false
                return cell
            case .content:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: R.reuseIdentifier.token_market,
                    for: indexPath,
                )!
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
        case .earning:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: R.reuseIdentifier.token_earning,
                for: indexPath,
            )!
            if let earning {
                cell.load(earning: earning)
            }
            return cell
        case .pending:
            switch indexPath.item {
            case 0:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: titleReuseIdentifier,
                    for: indexPath,
                ) as! TokenSectionTitleCell
                cell.label.text = R.string.localizable.pending()
                cell.disclosureIndicatorView.isHidden = true
                return cell
            default:
                let transaction = pendingSnapshots[indexPath.item - 1]
                return self.collectionView(
                    collectionView,
                    cellForTransaction: transaction,
                    at: indexPath,
                )
            }
        case .transactions:
            let row = transactionRow(at: indexPath)!
            switch row {
            case .title:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: titleReuseIdentifier,
                    for: indexPath,
                ) as! TokenSectionTitleCell
                cell.label.text = R.string.localizable.transactions()
                cell.disclosureIndicatorView.isHidden = false
                return cell
            case .emptyIndicator:
                return collectionView.dequeueReusableCell(
                    withReuseIdentifier: R.reuseIdentifier.no_transaction_indicator,
                    for: indexPath,
                )!
            case .transaction(let snapshot):
                return self.collectionView(
                    collectionView,
                    cellForTransaction: snapshot,
                    at: indexPath,
                )
            case .viewAll:
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: viewAllReuseIdentifier,
                    for: indexPath,
                ) as! UICollectionViewListCell
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
    
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath,
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: dateHeaderReuseIdentifier,
            for: indexPath,
        ) as! TokenTransactionDateHeaderView
        header.label.text = transactionSections[indexPath.section - Section.transactions.rawValue].date
        return header
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath,
    ) {
        let section = Section(collectionViewIndex: indexPath.section)
        guard section != .warning else {
            return
        }
        var corners: CACornerMask = []
        let isFirstSection = section != .transactions || indexPath.section == Section.transactions.rawValue
        let isLastSection = section != .transactions || indexPath.section == collectionView.numberOfSections - 1
        if isFirstSection && indexPath.item == 0 {
            corners.formUnion([.layerMinXMinYCorner, .layerMaxXMinYCorner])
        }
        if isLastSection && indexPath.item == collectionView.numberOfItems(inSection: indexPath.section) - 1 {
            corners.formUnion([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
        }
        cell.layer.cornerRadius = 8
        cell.layer.maskedCorners = corners
        cell.layer.masksToBounds = true
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        shouldHighlightItemAt indexPath: IndexPath,
    ) -> Bool {
        switch Section(collectionViewIndex: indexPath.section) {
        case .balance:
            false
        default:
            true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch Section(collectionViewIndex: indexPath.section) {
        case .warning, .balance:
            break
        case .market:
            viewMarket()
        case .earning:
            guard let productionID = earning?.topProductionID else {
                return
            }
            UIApplication.shared.homeNavigationController?.presentEarnPage(
                additionalURLQueries: ["production": productionID]
            )
        case .pending:
            switch indexPath.item {
            case 0:
                break
            default:
                view(transaction: pendingSnapshots[indexPath.item - 1])
            }
        case .transactions:
            let row = transactionRow(at: indexPath)!
            switch row {
            case .title, .viewAll:
                viewAllTransactions()
            case .transaction(let snapshot):
                view(transaction: snapshot)
            case .emptyIndicator:
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
        if #available(iOS 26.0, *), let source = sender as? UIBarButtonItem {
            sheet.popoverPresentationController?.sourceItem = source
        } else {
            sheet.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        }
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

extension TokenViewController {
    
    enum Section: Int, CaseIterable {
        
        case warning
        case balance
        case market
        case earning
        case pending
        case transactions
        
        init(collectionViewIndex: Int) {
            self = Section(rawValue: min(collectionViewIndex, Section.transactions.rawValue))!
        }
        
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
        case viewAll
    }
    
    struct TransactionSection {
        
        let date: String?
        let rows: [TransactionRow]
        
        static func sections(
            transactions: [Transaction],
            hasMore: Bool,
            dateRepresentation: (Transaction) -> String,
        ) -> [TransactionSection] {
            guard let firstTransaction = transactions.first else {
                return [.init(date: nil, rows: [.title, .emptyIndicator])]
            }
            var sections = [TransactionSection(date: nil, rows: [.title])]
            var date = dateRepresentation(firstTransaction)
            var rows: [TransactionRow] = [.transaction(firstTransaction)]
            for transaction in transactions.dropFirst() {
                let transactionDate = dateRepresentation(transaction)
                if transactionDate != date {
                    sections.append(.init(date: date, rows: rows))
                    date = transactionDate
                    rows = []
                }
                rows.append(.transaction(transaction))
            }
            if hasMore {
                rows.append(.viewAll)
            }
            sections.append(.init(date: date, rows: rows))
            return sections
        }
        
    }
    
    private func reloadMarket(result: MarketResult) {
        self.market = result
        let indexPath = IndexPath(item: MarketRow.content.rawValue, section: Section.market.rawValue)
        UIView.performWithoutAnimation {
            collectionView.reloadItems(at: [indexPath])
        }
    }
    
    private func reloadChart(_ points: [ChartView.Point]) {
        self.chartPoints = points
        let indexPath = IndexPath(item: MarketRow.content.rawValue, section: Section.market.rawValue)
        UIView.performWithoutAnimation {
            collectionView.reloadItems(at: [indexPath])
        }
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
            case .failure:
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.loadMarketsFromRemote(assetID: assetID)
                }
            }
        }
    }
    
}
