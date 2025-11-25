import UIKit
import MixinServices

final class TradeOrdersViewController: UIViewController {
    
    private typealias DateRepresentation = String
    private typealias OrderID = String
    private typealias DiffableDataSource = UICollectionViewDiffableDataSource<DateRepresentation, OrderID>
    private typealias DataSourceSnapshot = NSDiffableDataSourceSnapshot<DateRepresentation, OrderID>
    
    @IBOutlet weak var filtersScrollView: UIScrollView!
    @IBOutlet weak var filtersStackView: UIStackView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let walletFilterView = WalletFilterView()
    private let typeFilterView = TypeFilterView()
    private let statusFilterView = StatusFilterView()
    private let dateFilterView = TransactionHistoryDateFilterView()
    private let queue = OperationQueue()
    
    private var filter: TradeOrder.Filter
    private var sorting: TradeOrder.Sorting = .newest
    private var dataSource: DiffableDataSource!
    private var viewModels: [OrderID: TradeOrderViewModel] = [:]
    
    private var loadPreviousPageIndexPath: IndexPath?
    private var firstItem: TradeOrderViewModel?
    
    private var loadNextPageIndexPath: IndexPath?
    private var lastItem: TradeOrderViewModel?
    
    private var pendingOrdersLoader: PendingTradeOrderLoader?
    
    init(wallet: Wallet) {
        self.filter = TradeOrder.Filter(wallets: [wallet])
        let nib = R.nib.tradeOrdersView
        super.init(nibName: nib.name, bundle: nib.bundle)
        self.queue.maxConcurrentOperationCount = 1
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = R.string.localizable.orders()
        reloadRightBarButtonItem(sorting: sorting)
        
        walletFilterView.reloadData(wallets: filter.wallets)
        walletFilterView.button.addTarget(self, action: #selector(pickWallets(_:)), for: .touchUpInside)
        typeFilterView.reloadData(type: filter.type)
        typeFilterView.button.menu = UIMenu(children: typeFilterActions(selectedType: filter.type))
        statusFilterView.reloadData(status: filter.status)
        statusFilterView.button.menu = UIMenu(children: statusFilterActions(status: filter.status))
        dateFilterView.reloadData(startDate: filter.startDate, endDate: filter.endDate)
        dateFilterView.button.addTarget(self, action: #selector(pickDates(_:)), for: .touchUpInside)
        for view in [walletFilterView, typeFilterView, statusFilterView, dateFilterView] {
            view.backgroundColor = R.color.background()
            filtersStackView.addArrangedSubview(view)
        }
        
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { (_, _) in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: nil, top: .fixed(10), trailing: nil, bottom: .fixed(10))
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(70))
            let group: NSCollectionLayoutGroup = .vertical(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
            ]
            return section
        }
        collectionView.delegate = self
        collectionView.register(R.nib.tradeOrderCell)
        dataSource = DiffableDataSource(collectionView: collectionView) { [weak self] (collectionView, indexPath, orderID) in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.trade_order, for: indexPath)!
            if let viewModel = self?.viewModels[orderID] {
                cell.load(viewModel: viewModel)
            }
            return cell
        }
        let header = UICollectionView.SupplementaryRegistration<HeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] (view, _, indexPath) in
            view.label.text = self?.dataSource.sectionIdentifier(for: indexPath.section)
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        
        reloadData()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ordersDidSave(_:)),
            name: Web3OrderDAO.didSaveNotification,
            object: nil
        )
        syncOrders(wallets: filter.wallets)
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
        pendingOrdersLoader?.start(after: 0)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pendingOrdersLoader?.pause()
    }
    
    @objc private func pickWallets(_ sender: Any) {
        let selector = WalletSelectorViewController(
            intent: .pickSwapOrderFilter(selectedWallets: filter.wallets),
            excluding: nil,
            supportingChainWith: nil
        )
        selector.delegate = self
        present(selector, animated: true)
    }
    
    @objc private func pickDates(_ sender: Any) {
        let picker = TransactionHistoryDatePickerViewController(startDate: filter.startDate, endDate: filter.endDate)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func ordersDidSave(_ notification: Notification) {
        if let orders = notification.userInfo?[Web3OrderDAO.ordersUserInfoKey] as? [TradeOrder], orders.count == 1 {
            // If there's only 1 item is saved, reduce db access by reloading it in place
            let order = orders[0]
            if !filter.isIncluded(order: order) {
                // The order will never show in this view, no need to load
                return
            }
            if viewModels[order.orderID] != nil {
                let operation = ReloadSingleItemOperation(viewController: self, orderID: order.orderID)
                queue.addOperation(operation)
                return
            }
        }
        let behavior: LoadLocalDataOperation.Behavior
        if let firstVisibleIndexPath = collectionView.indexPathsForSelectedItems?.sorted(by: <).first,
           let orderID = dataSource.itemIdentifier(for: firstVisibleIndexPath),
           let firstItem = viewModels[orderID]
        {
            behavior = .reloadVisibleItems(offset: firstItem)
        } else {
            behavior = .reload
        }
        Logger.general.debug(category: "SwapOrders", message: "Previous canary cleared")
        loadPreviousPageIndexPath = nil
        Logger.general.debug(category: "SwapOrders", message: "Next canary cleared")
        loadNextPageIndexPath = nil
        let operation = LoadLocalDataOperation(
            viewController: self,
            behavior: behavior,
            filter: filter,
            sorting: sorting
        )
        queue.addOperation(operation)
    }
    
    private func reloadRightBarButtonItem(sorting: TradeOrder.Sorting) {
        let rightBarButtonItem: UIBarButtonItem
        if let item = navigationItem.rightBarButtonItem {
            rightBarButtonItem = item
        } else {
            rightBarButtonItem = .tintedIcon(image: R.image.navigation_filter(), target: nil, action: nil)
            navigationItem.rightBarButtonItem = rightBarButtonItem
        }
        let actions = orderActions(selectedOrder: sorting)
        rightBarButtonItem.menu = UIMenu(children: actions)
    }
    
    private func updateEmptyIndicator(numberOfItems: Int) {
        collectionView.checkEmpty(
            dataCount: numberOfItems,
            text: R.string.localizable.no_orders(),
            photo: R.image.emptyIndicator.ic_data()!
        )
    }
    
    private func withTableViewContentOffsetManaged(_ block: () -> Void) {
        var tableBottomContentOffsetY: CGFloat {
            collectionView.adjustedContentInset.vertical + collectionView.contentSize.height - collectionView.frame.height
        }
        
        let distanceToBottom = collectionView.contentSize.height - collectionView.contentOffset.y
        let wasAtTableTop = collectionView.contentOffset.y < 1
        let wasAtTableBottom = abs(collectionView.contentOffset.y - tableBottomContentOffsetY) < 1
        block()
        collectionView.layoutIfNeeded() // Important, ensures `collectionView.contentSize` is correct
        let contentOffset: CGPoint
        if wasAtTableTop {
            Logger.general.debug(category: "SwapOrders", message: "Going to table top")
            contentOffset = .zero
        } else if wasAtTableBottom {
            Logger.general.debug(category: "SwapOrders", message: "Going to table bottom")
            contentOffset = CGPoint(x: 0, y: tableBottomContentOffsetY)
        } else {
            Logger.general.debug(category: "SwapOrders", message: "Going to managed offset")
            let contentSizeAfter = collectionView.contentSize
            contentOffset = CGPoint(
                x: collectionView.contentOffset.x,
                y: max(collectionView.contentOffset.y, contentSizeAfter.height - distanceToBottom)
            )
        }
        collectionView.setContentOffset(contentOffset, animated: false)
    }
    
    private func reloadData(sorting: TradeOrder.Sorting) {
        self.sorting = sorting
        reloadRightBarButtonItem(sorting: sorting)
        reloadData()
    }
    
    private func reloadData(filterType type: TradeOrder.OrderType?) {
        filter.type = type
        let actions = typeFilterActions(selectedType: filter.type)
        typeFilterView.button.menu = UIMenu(children: actions)
        typeFilterView.reloadData(type: type)
        reloadData()
    }
    
    private func reloadData(status: TradeOrder.Status?) {
        filter.status = status
        let actions = statusFilterActions(status: filter.status)
        statusFilterView.button.menu = UIMenu(children: actions)
        statusFilterView.reloadData(status: status)
        reloadData()
    }
    
    private func reloadData() {
        queue.cancelAllOperations()
        loadPreviousPageIndexPath = nil
        loadNextPageIndexPath = nil
        let operation = LoadLocalDataOperation(
            viewController: self,
            behavior: .reload,
            filter: filter,
            sorting: sorting
        )
        queue.addOperation(operation)
    }
    
    private func syncOrders(wallets: [Wallet]) {
        let jobs = wallets.map { wallet in
            let walletID = switch wallet {
            case .privacy:
                myUserId
            case .common(let wallet):
                wallet.walletID
            }
            return SyncWeb3OrdersJob(walletID: walletID)
        }
        for job in jobs {
            ConcurrentJobQueue.shared.addJob(job: job)
        }
    }
    
}

extension TradeOrdersViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath), let viewModel = viewModels[id] else {
            return
        }
        let viewController = TradeOrderViewController(viewModel: viewModel)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}

extension TradeOrdersViewController: WalletSelectorViewController.Delegate {
    
    func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectWallet wallet: Wallet) {
        
    }
    
    func walletSelectorViewController(_ viewController: WalletSelectorViewController, didSelectMultipleWallets wallets: [Wallet]) {
        dismiss(animated: true)
        filter.wallets = wallets
        walletFilterView.reloadData(wallets: wallets)
        reloadData()
        syncOrders(wallets: wallets)
    }
    
}

extension TradeOrdersViewController: TransactionHistoryDatePickerViewControllerDelegate {
    
    func transactionHistoryDatePickerViewController(
        _ controller: TransactionHistoryDatePickerViewController,
        didPickStartDate startDate: Date?,
        endDate: Date?
    ) {
        filter.startDate = startDate
        filter.endDate = endDate
        dateFilterView.reloadData(startDate: startDate, endDate: endDate)
        filtersScrollView.layoutIfNeeded()
        let rightMost = CGPoint(
            x: filtersScrollView.contentSize.width - filtersScrollView.frame.width,
            y: filtersScrollView.contentOffset.y
        )
        filtersScrollView.setContentOffset(rightMost, animated: false)
        reloadData()
    }
    
}

extension TradeOrdersViewController {
    
    private final class WalletFilterView: TransactionHistoryFilterView {
        
        private weak var imageView: UIImageView?
        
        // Empty wallets for disable filtering
        func reloadData(wallets: [Wallet]) {
            switch wallets.count {
            case 0:
                label.text = R.string.localizable.wallets()
                imageView?.removeFromSuperview()
                imageView = nil
            case 1:
                let wallet = wallets[0]
                label.text = wallet.localizedName
                switch wallet {
                case .privacy:
                    if imageView == nil {
                        let imageView = UIImageView(image: R.image.privacy_wallet())
                        imageView.contentMode = .scaleAspectFit
                        contentStackView.insertArrangedSubview(imageView, at: 1)
                        imageView.snp.makeConstraints { make in
                            make.width.height.equalTo(18)
                        }
                        self.imageView = imageView
                    }
                case .common:
                    imageView?.removeFromSuperview()
                    imageView = nil
                }
            default:
                label.text = R.string.localizable.wallets_count(wallets.count)
                imageView?.removeFromSuperview()
                imageView = nil
            }
        }
        
    }
    
    private final class TypeFilterView: TransactionHistoryFilterView {
        
        func reloadData(type: TradeOrder.OrderType?) {
            label.text = switch type {
            case .none:
                R.string.localizable.type()
            case .swap:
                R.string.localizable.order_type_swap()
            case .limit:
                R.string.localizable.order_type_limit()
            }
        }
        
    }
    
    private final class StatusFilterView: TransactionHistoryFilterView {
        
        func reloadData(status: TradeOrder.Status?) {
            label.text = switch status {
            case .none:
                R.string.localizable.all()
            case .pending:
                R.string.localizable.pending()
            case .done:
                R.string.localizable.done()
            case .other:
                R.string.localizable.other()
            }
        }
        
    }
    
    private final class HeaderView: UICollectionReusableView {
        
        private(set) weak var label: UILabel!
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            loadLabel()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            loadLabel()
        }
        
        private func loadLabel() {
            backgroundColor = R.color.background()
            let label = UILabel()
            addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.equalToSuperview().multipliedBy(1.2)
            }
            label.font = .preferredFont(forTextStyle: .caption1)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = R.color.text_quaternary()
            self.label = label
        }
        
    }
    
}

extension TradeOrdersViewController {
    
    private class ReloadSingleItemOperation: Operation {
        
        private let orderID: String
        
        private weak var viewController: TradeOrdersViewController?
        
        init(viewController: TradeOrdersViewController?, orderID: String) {
            self.viewController = viewController
            self.orderID = orderID
        }
        
        override func main() {
            guard let order = Web3OrderDAO.shared.order(id: orderID) else {
                return
            }
            let wallet: Wallet
            if order.walletID == myUserId {
                wallet = .privacy
            } else if let commonWallet = Web3WalletDAO.shared.wallet(id: order.walletID) {
                wallet = .common(commonWallet)
            } else {
                return
            }
            let payToken = TokenDAO.shared.swapOrderToken(id: order.payAssetID)
            ?? Web3TokenDAO.shared.swapOrderToken(id: order.payAssetID)
            let receiveToken = TokenDAO.shared.swapOrderToken(id: order.receiveAssetID)
            ?? Web3TokenDAO.shared.swapOrderToken(id: order.receiveAssetID)
            let viewModel = TradeOrderViewModel(order: order, wallet: wallet, payToken: payToken, receiveToken: receiveToken)
            Logger.general.debug(category: "SwapOrders", message: "Reload id: \(orderID)")
            DispatchQueue.main.sync {
                guard let viewController, !isCancelled else {
                    return
                }
                viewController.viewModels[viewModel.orderID] = viewModel
                var dataSnapshot = viewController.dataSource.snapshot()
                dataSnapshot.reloadItems([viewModel.orderID])
                viewController.dataSource.apply(dataSnapshot, animatingDifferences: false)
            }
        }
        
    }
    
    private class LoadLocalDataOperation: Operation {
        
        enum Behavior: CustomDebugStringConvertible {
            
            // Full reload from the very first item
            case reload
            
            // Reload items after the offset. `offset` is included in the results
            case reloadVisibleItems(offset: TradeOrderViewModel)
            
            // Load items before the offset. `offset` is not included
            case prepend(offset: TradeOrderViewModel)
            
            // Load items after the offset. `offset` is not included
            case append(offset: TradeOrderViewModel)
            
            var debugDescription: String {
                switch self {
                case .reload:
                    "reload"
                case .reloadVisibleItems(let offset):
                    "reloadVisibleItems(\(offset.orderID))"
                case .prepend(let offset):
                    "prepend(\(offset.orderID))"
                case .append(let offset):
                    "append(\(offset.orderID))"
                }
            }
            
        }
        
        private let behavior: Behavior
        private let filter: TradeOrder.Filter
        private let sorting: TradeOrder.Sorting
        
        private let limit = 50
        private let loadMoreThreshold = 5
        
        private weak var viewController: TradeOrdersViewController?
        
        init(
            viewController: TradeOrdersViewController?,
            behavior: Behavior,
            filter: TradeOrder.Filter,
            sorting: TradeOrder.Sorting
        ) {
            self.viewController = viewController
            self.behavior = behavior
            self.filter = filter
            self.sorting = sorting
            assert(limit > loadMoreThreshold)
        }
        
        override func main() {
            Logger.general.debug(category: "SwapOrders", message: "Load with behavior: \(behavior), filter: \(filter.description), order: \(sorting)")
            let offset: Web3OrderDAO.Offset? = switch behavior {
            case .reload:
                    .none
            case .reloadVisibleItems(let offset):
                    .after(offset: offset, includesOffset: true)
            case .prepend(let offset):
                    .before(offset: offset, includesOffset: false)
            case .append(let offset):
                    .after(offset: offset, includesOffset: false)
            }
            
            let orders = Web3OrderDAO.shared.orders(
                offset: offset,
                filter: filter,
                sorting: sorting,
                limit: limit
            )
            
            let wallets: [String: Wallet]
            if filter.wallets.isEmpty {
                var allWallets: [String: Wallet] = [myUserId: .privacy]
                for wallet in Web3WalletDAO.shared.wallets() {
                    allWallets[wallet.walletID] = .common(wallet)
                }
                wallets = allWallets
            } else {
                wallets = filter.wallets.reduce(into: [:]) { results, wallet in
                    switch wallet {
                    case .privacy:
                        results[myUserId] = wallet
                    case .common(let web3Wallet):
                        results[web3Wallet.walletID] = wallet
                    }
                }
            }
            
            let tokens = Web3OrderDAO.shared.tradeOrderTokens(orders: orders)
            
            let viewModels: [TradeOrderViewModel] = orders.compactMap { order in
                guard let wallet = wallets[order.walletID] else {
                    return nil
                }
                return TradeOrderViewModel(
                    order: order,
                    wallet: wallet,
                    payToken: tokens[order.payAssetID],
                    receiveToken: tokens[order.receiveAssetID]
                )
            }
            
            Logger.general.debug(category: "SwapOrders", message: "Loaded \(viewModels.count) items:\n\(viewModels.map(\.orderID))")
            
            var dataSnapshot: DataSourceSnapshot
            switch behavior {
            case .reload, .reloadVisibleItems:
                dataSnapshot = DataSourceSnapshot()
            case .prepend, .append:
                let snapshot = DispatchQueue.main.sync {
                    viewController?.dataSource.snapshot()
                }
                if let snapshot {
                    dataSnapshot = snapshot
                } else {
                    return
                }
            }
            
            switch sorting {
            case .newest, .oldest:
                switch offset {
                case .before:
                    for viewModel in viewModels.reversed() {
                        let date = if let date = DateFormatter.iso8601Full.date(from: viewModel.createdAt) {
                            DateFormatter.dateSimple.string(from: date)
                        } else {
                            viewModel.createdAt
                        }
                        if dataSnapshot.sectionIdentifiers.contains(date) {
                            if let firstItem = dataSnapshot.itemIdentifiers(inSection: date).first {
                                dataSnapshot.insertItems([viewModel.orderID], beforeItem: firstItem)
                            } else {
                                dataSnapshot.appendItems([viewModel.orderID], toSection: date)
                            }
                        } else {
                            if let firstSection = dataSnapshot.sectionIdentifiers.first {
                                dataSnapshot.insertSections([date], beforeSection: firstSection)
                            } else {
                                dataSnapshot.appendSections([date])
                            }
                            dataSnapshot.appendItems([viewModel.orderID], toSection: date)
                        }
                    }
                case .after, .none:
                    for viewModel in viewModels {
                        let date = if let date = DateFormatter.iso8601Full.date(from: viewModel.createdAt) {
                            DateFormatter.dateSimple.string(from: date)
                        } else {
                            viewModel.createdAt
                        }
                        if !dataSnapshot.sectionIdentifiers.reversed().contains(date) {
                            dataSnapshot.appendSections([date])
                        }
                        dataSnapshot.appendItems([viewModel.orderID], toSection: date)
                    }
                }
            }
            
            DispatchQueue.main.sync {
                guard let controller = viewController, !isCancelled else {
                    return
                }
                controller.sorting = sorting
                switch behavior {
                case .reload, .reloadVisibleItems:
                    controller.viewModels = viewModels.reduce(into: [:]) { results, item in
                        results[item.orderID] = item
                    }
                case .prepend, .append:
                    for viewModel in viewModels {
                        controller.viewModels[viewModel.orderID] = viewModel
                    }
                }
                switch behavior {
                case .reload:
                    controller.loadPreviousPageIndexPath = nil
                    controller.firstItem = nil
                    Logger.general.debug(category: "SwapOrders", message: "Going to table top by reloading")
                    controller.collectionView.setContentOffset(.zero, animated: false)
                    controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                case .reloadVisibleItems:
                    controller.withTableViewContentOffsetManaged {
                        if let item = viewModels.first {
                            controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                            controller.firstItem = item
                            Logger.general.debug(category: "SwapOrders", message: "Set previous canary \(item.orderID)")
                        } else {
                            controller.loadPreviousPageIndexPath = nil
                            controller.firstItem = nil
                            Logger.general.debug(category: "SwapOrders", message: "Previous canary cleared")
                        }
                        controller.dataSource.applySnapshotUsingReloadData(dataSnapshot)
                    }
                case .prepend:
                    controller.withTableViewContentOffsetManaged {
                        if let item = viewModels.first {
                            controller.loadPreviousPageIndexPath = IndexPath(row: 0, section: 0)
                            controller.firstItem = item
                            Logger.general.debug(category: "SwapOrders", message: "Set previous canary \(item.orderID)")
                        } else {
                            controller.loadPreviousPageIndexPath = nil
                            controller.firstItem = nil
                            Logger.general.debug(category: "SwapOrders", message: "Previous canary cleared")
                        }
                        controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                    }
                case .append:
                    controller.dataSource.apply(dataSnapshot, animatingDifferences: false)
                }
                controller.updateEmptyIndicator(numberOfItems: dataSnapshot.numberOfItems)
                switch behavior {
                case .prepend:
                    // Index path changes after prepending
                    if let lastItem = controller.lastItem {
                        controller.loadNextPageIndexPath = controller.dataSource.indexPath(for: lastItem.orderID)
                    }
                case .reload, .reloadVisibleItems, .append:
                    if viewModels.count >= limit,
                       let canary = viewModels.last,
                       let indexPath = controller.dataSource.indexPath(for: canary.orderID)
                    {
                        Logger.general.debug(category: "SwapOrders", message: "Set next canary \(canary.orderID)")
                        controller.loadNextPageIndexPath = indexPath
                        controller.lastItem = canary
                    } else {
                        Logger.general.debug(category: "SwapOrders", message: "Next canary cleared")
                        controller.loadNextPageIndexPath = nil
                        controller.lastItem = nil
                    }
                }
                controller.pendingOrdersLoader?.pause()
                let pendingOrderIDs = controller.viewModels.values.compactMap { viewModel in
                    switch viewModel.state.knownCase {
                    case .created, .pending, .cancelling:
                        viewModel.orderID
                    default:
                        nil
                    }
                }
                if !pendingOrderIDs.isEmpty {
                    let pendingOrdersLoader = PendingTradeOrderLoader(
                        behavior: .watchOrders(orderIDs: pendingOrderIDs)
                    )
                    controller.pendingOrdersLoader = pendingOrdersLoader
                    pendingOrdersLoader.start(after: pendingOrdersLoader.refreshInterval)
                }
            }
        }
    }
    
}

extension TradeOrdersViewController {
    
    private func orderActions(selectedOrder order: TradeOrder.Sorting) -> [UIAction] {
        let actions = [
            UIAction(
                title: R.string.localizable.recent(),
                image: R.image.order_newest(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(sorting: .newest) }
            ),
            UIAction(
                title: R.string.localizable.oldest(),
                image: R.image.order_oldest(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(sorting: .oldest) }
            ),
        ]
        switch order {
        case .newest:
            actions[0].state = .on
        case .oldest:
            actions[1].state = .on
        }
        return actions
    }
    
    private func typeFilterActions(selectedType type: TradeOrder.OrderType?) -> [UIAction] {
        let actions = [
            UIAction(
                title: R.string.localizable.all(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: nil) }
            ),
            UIAction(
                title: R.string.localizable.order_type_swap(),
                image: R.image.filter_swap(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: .swap) }
            ),
            UIAction(
                title: R.string.localizable.order_type_limit(),
                image: R.image.filter_swap_limit(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(filterType: .limit) }
            ),
        ]
        switch type {
        case .none:
            actions[0].state = .on
        case .swap:
            actions[1].state = .on
        case .limit:
            actions[2].state = .on
        }
        return actions
    }
    
    private func statusFilterActions(status: TradeOrder.Status?) -> [UIAction] {
        let actions = [
            UIAction(
                title: R.string.localizable.all(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(status: nil) }
            ),
            UIAction(
                title: R.string.localizable.pending(),
                image: R.image.filter_pending(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(status: .pending) }
            ),
            UIAction(
                title: R.string.localizable.done(),
                image: R.image.filter_done(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(status: .done) }
            ),
            UIAction(
                title: R.string.localizable.other(),
                state: .off,
                handler: { [weak self] _ in self?.reloadData(status: .other) }
            ),
        ]
        switch status {
        case .none:
            actions[0].state = .on
        case .pending:
            actions[1].state = .on
        case .done:
            actions[2].state = .on
        case .other:
            actions[3].state = .on
        }
        return actions
    }
    
}
