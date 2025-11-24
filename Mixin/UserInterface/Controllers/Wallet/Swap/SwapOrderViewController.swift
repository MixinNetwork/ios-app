import UIKit
import MixinServices

final class SwapOrderViewController: UITableViewController {
    
    private var viewModel: SwapOrderViewModel
    private var actions: [Action] = []
    private var infoRows: [InfoRow] = []
    private var loader: PendingSwapOrderLoader?
    
    init(viewModel: SwapOrderViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_secondary()
        
        title = R.string.localizable.order_details()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.order_details(),
            wallet: .privacy
        )
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        
        tableView.backgroundColor = R.color.background_secondary()
        tableView.register(R.nib.swapOrderHeaderCell)
        tableView.register(R.nib.multipleAssetChangeCell)
        tableView.register(R.nib.authenticationPreviewInfoCell)
        tableView.register(R.nib.authenticationPreviewWalletCell)
        tableView.register(R.nib.authenticationPreviewCompactInfoCell)
        tableView.register(R.nib.swapOrderIDCell)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadOrderIfContains(_:)),
            name: Web3OrderDAO.didSaveNotification,
            object: nil
        )
        reloadData(viewModel: viewModel)
        switch viewModel.state.knownCase {
        case .created, .pending:
            if let type = viewModel.type.knownCase {
                loader = PendingSwapOrderLoader(
                    behavior: .watchOrder(id: viewModel.orderID, type: type)
                )
            }
        default:
            break
        }
        
        reporter.report(event: .tradeDetail)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loader?.start(after: 0)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        loader?.pause()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .header:
            1
        case .info:
            infoRows.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .header:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.swap_order_header, for: indexPath)!
            cell.load(viewModel: viewModel)
            cell.actionView.delegate = self
            cell.actionView.actions = actions.map { $0.asPillAction() }
            return cell
        case .info:
            switch infoRows[indexPath.row] {
            case .paid:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multiple_asset_change, for: indexPath)!
                cell.titleLabel.text = R.string.localizable.swap_order_paid().uppercased()
                cell.reloadData(changes: [viewModel.paying], style: .outcome)
                cell.contentTopConstraint.constant = 20
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .receives:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multiple_asset_change, for: indexPath)!
                cell.titleLabel.text = switch viewModel.state.knownCase {
                case .created, .pending, .failed, .cancelling, .cancelled, .expired, .none:
                    R.string.localizable.estimated_receive().uppercased()
                case .success:
                    R.string.localizable.swap_order_received().uppercased()
                }
                cell.reloadData(changes: viewModel.receivings, style: .income)
                cell.contentTopConstraint.constant = 10
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case let .filling(filling):
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
                cell.captionLabel.text = R.string.localizable.trade_filled().uppercased()
                cell.setPrimaryLabel(usesBoldFont: false)
                cell.primaryLabel.text = filling.percentage
                cell.secondaryLabel.text = filling.amount
                cell.trailingContent = nil
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .price:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
                cell.captionLabel.text = switch viewModel.type.knownCase {
                case .swap, .none:
                    R.string.localizable.price().uppercased()
                case .limit:
                    R.string.localizable.limit_price().uppercased()
                }
                cell.primaryLabel.text = viewModel.receivePrice
                cell.secondaryLabel.text = viewModel.sendPrice
                cell.setPrimaryLabel(usesBoldFont: false)
                cell.trailingContent = nil
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .wallet:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_wallet, for: indexPath)!
                cell.captionLabel.text = R.string.localizable.wallet().uppercased()
                switch viewModel.wallet {
                case .privacy:
                    cell.nameLabel.text = R.string.localizable.privacy_wallet()
                    cell.iconImageView.isHidden = false
                case .common(let wallet):
                    cell.nameLabel.text = wallet.name
                    cell.iconImageView.isHidden = true
                }
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case let .expiration(expiration):
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = R.string.localizable.trade_expiration().uppercased()
                cell.setContent(expiration)
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .type:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = R.string.localizable.type().uppercased()
                cell.setContent(viewModel.type.localizedDescription)
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .createdAt:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = R.string.localizable.created().uppercased()
                cell.setContent(viewModel.createdAtRepresentation)
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .orderID:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.swap_order_id, for: indexPath)!
                cell.contentLabel.text = viewModel.orderID
                cell.delegate = self
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 10 : .leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "trade_detail"])
    }
    
    @objc private func reloadOrderIfContains(_ notification: Notification) {
        guard let orders = notification.userInfo?[Web3OrderDAO.ordersUserInfoKey] as? [SwapOrder] else {
            return
        }
        guard let order = orders.first(where: { $0.orderID == viewModel.orderID }) else {
            return
        }
        let newViewModel = SwapOrderViewModel(
            order: order,
            wallet: viewModel.wallet,
            payToken: viewModel.payToken,
            receiveToken: viewModel.receiveToken
        )
        reloadData(viewModel: newViewModel)
    }
    
    private func reloadData(viewModel: SwapOrderViewModel) {
        self.viewModel = viewModel
        self.actions = Action.actions(orderState: viewModel.state.knownCase)
        self.infoRows = InfoRow.rows(viewModel: viewModel)
        self.tableView.reloadData()
    }
    
    private func cancelOrder() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        RouteAPI.cancelSwapOrder(id: viewModel.orderID) { result in
            switch result {
            case .success(let order):
                hud.hide()
                DispatchQueue.global().async {
                    Web3OrderDAO.shared.save(orders: [order])
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
}

extension SwapOrderViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension SwapOrderViewController: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        switch actions[index] {
        case .tradeAgain:
            if let navigationController {
                var viewControllers = navigationController.viewControllers
                if let index = viewControllers.lastIndex(where: { $0 is MixinSwapViewController }) {
                    viewControllers.removeLast(viewControllers.count - index)
                }
                let mode: SwapViewController.Mode
                switch viewModel.type.knownCase {
                case .limit:
                    mode = .advanced
                case .swap, .none:
                    mode = .simple
                }
                let swap = switch viewModel.wallet {
                case .privacy:
                    MixinSwapViewController(
                        mode: mode,
                        sendAssetID: viewModel.payAssetID,
                        receiveAssetID: viewModel.receiveAssetID,
                        referral: nil
                    )
                case .common(let wallet):
                    Web3SwapViewController(
                        wallet: wallet,
                        mode: mode,
                        sendAssetID: viewModel.payAssetID,
                        receiveAssetID: viewModel.receiveAssetID
                    )
                }
                viewControllers.append(swap)
                navigationController.setViewControllers(viewControllers, animated: true)
                reporter.report(event: .tradeStart, tags: ["wallet": "main", "source": "trade_detail"])
            }
        case .cancelOrder:
            let confirmation = UIAlertController(title: "Cancel Order?", message: nil, preferredStyle: .alert)
            confirmation.addAction(UIAlertAction(title: "Keep Waiting", style: .cancel, handler: nil))
            confirmation.addAction(UIAlertAction(title: "Cancel Order", style: .destructive, handler: { [weak self] _ in
                self?.cancelOrder()
            }))
            present(confirmation, animated: true)
        case .sharePair:
            guard let navigationController else {
                return
            }
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            let oneSideStablecoinPair = OneSideStablecoinPair(order: viewModel)
            let focusAssetID, focusAssetSymbol, buyAction, sellAction: String
            if let pair = oneSideStablecoinPair {
                focusAssetID = pair.nonStablecoinAssetID
                focusAssetSymbol = pair.nonStablecoinSymbol
                buyAction = "mixin://mixin.one/swap?input=\(pair.stablecoinAssetID)&output=\(pair.nonStablecoinAssetID)"
                sellAction = "mixin://mixin.one/swap?input=\(pair.nonStablecoinAssetID)&output=\(pair.stablecoinAssetID)"
            } else {
                focusAssetID = viewModel.receiveAssetID
                focusAssetSymbol = viewModel.receiveSymbol
                buyAction = "mixin://mixin.one/swap?input=\(viewModel.payAssetID)&output=\(viewModel.receiveAssetID)"
                sellAction = "mixin://mixin.one/swap?input=\(viewModel.receiveAssetID)&output=\(viewModel.payAssetID)"
            }
            RouteAPI.markets(id: focusAssetID, queue: .main) { [viewModel] result in
                hud.hide()
                let description: String? = switch result {
                case let .success(market):
                    """
                    🔥 \(market.name) (\(market.symbol))

                    📈 \(R.string.localizable.market_cap()): \(market.localizedMarketCap ?? "")
                    🏷️ \(R.string.localizable.price()): \(market.localizedPrice)
                    💰 \(R.string.localizable.price_change_24h()): \(market.localizedPriceChangePercentage24H ?? "")
                    """
                case .failure:
                    """
                    🏷️ \(R.string.localizable.price()): \(viewModel.receivePrice ?? "Unknown")
                    """
                }
                let actions: [AppCardData.V1Content.Action] = [
                    .init(
                        action: buyAction,
                        color: "#50BD5C",
                        label: R.string.localizable.buy_token(focusAssetSymbol)
                    ),
                    .init(
                        action: sellAction,
                        color: "#DB454F",
                        label: R.string.localizable.sell_token(focusAssetSymbol)
                    ),
                    .init(
                        action: "mixin://mixin.one/markets/\(focusAssetID)",
                        color: "#3D75E3",
                        label: focusAssetSymbol + " " + R.string.localizable.market()
                    )
                ]
                let content = AppCardData.V1Content(
                    appID: BotUserID.mixinRoute,
                    cover: nil,
                    title: R.string.localizable.trade() + " " + viewModel.exchangingSymbolRepresentation,
                    description: description,
                    actions: actions,
                    updatedAt: nil,
                    isShareable: true
                )
                let receiverSelector = MessageReceiverViewController.instance(content: .appCard(.v1(content)))
                navigationController.pushViewController(receiverSelector, animated: true)
            }
        }
    }
    
}

extension SwapOrderViewController: SwapOrderIDCell.Delegate {
    
    func swapOrderIDCellRequestCopy(_ cell: SwapOrderIDCell) {
        UIPasteboard.general.string = viewModel.orderID
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}

extension SwapOrderViewController {
    
    private enum Section: Int, CaseIterable {
        case header
        case info
    }
    
    private enum Action {
        
        case tradeAgain
        case cancelOrder
        case sharePair
        
        static func actions(orderState: SwapOrder.State?) -> [Action] {
            switch orderState {
            case .created, .pending:
                [.cancelOrder, .sharePair]
            case .none, .success, .failed, .cancelling, .cancelled, .expired:
                [.tradeAgain, .sharePair]
            }
        }
        
        func asPillAction() -> PillActionView.Action {
            switch self {
            case .tradeAgain:
                    .init(title: R.string.localizable.trade_again())
            case .cancelOrder:
                    .init(title: R.string.localizable.cancel_order(), style: .destructive)
            case .sharePair:
                    .init(title: R.string.localizable.share_pair())
            }
        }
        
    }
    
    private enum InfoRow {
        
        case paid
        case receives
        case filling(SwapOrderViewModel.Filling)
        case price
        case wallet
        case expiration(String)
        case type
        case createdAt
        case orderID
        
        static func rows(viewModel: SwapOrderViewModel) -> [InfoRow] {
            var rows: [InfoRow] = [.paid, .receives]
            if let filling = viewModel.filling {
                rows.append(.filling(filling))
            }
            rows.append(contentsOf: [.price, .wallet])
            if let expiration = viewModel.expiration {
                rows.append(.expiration(expiration))
            }
            rows.append(contentsOf: [.type, .createdAt, .orderID])
            return rows
        }
        
    }
    
    private struct OneSideStablecoinPair {
        
        let stablecoinAssetID: String
        let stablecoinSymbol: String
        let nonStablecoinAssetID: String
        let nonStablecoinSymbol: String
        
        init?(order: SwapOrderViewModel) {
            let payingStablecoin = AssetID.stablecoins.contains(order.payAssetID)
            let receivingStablecoin = AssetID.stablecoins.contains(order.receiveAssetID)
            if payingStablecoin && !receivingStablecoin {
                stablecoinAssetID = order.payAssetID
                stablecoinSymbol = order.paySymbol
                nonStablecoinAssetID = order.receiveAssetID
                nonStablecoinSymbol = order.receiveSymbol
            } else if !payingStablecoin && receivingStablecoin {
                stablecoinAssetID = order.receiveAssetID
                stablecoinSymbol = order.receiveSymbol
                nonStablecoinAssetID = order.payAssetID
                nonStablecoinSymbol = order.paySymbol
            } else {
                return nil
            }
        }
        
    }
    
}
