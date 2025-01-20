import UIKit
import MixinServices

final class SwapOrderViewController: UITableViewController {
    
    private enum Section: Int, CaseIterable {
        case header
        case info
    }
    
    private enum InfoRow: Int, CaseIterable {
        case paid
        case receive
        case price
        case type
        case createdAt
        case orderID
    }
    
    private let order: SwapOrderItem
    private let payAmount: String
    private let receivePrice: String
    private let sendPrice: String
    
    init(order: SwapOrderItem) {
        self.order = order
        self.payAmount = CurrencyFormatter.localizedString(
            from: -order.payAmount,
            format: .precision,
            sign: .always,
            symbol: .custom(order.paySymbol)
        )
        self.receivePrice = SwapQuote.priceRepresentation(
            sendAmount: order.payAmount,
            sendSymbol: order.paySymbol,
            receiveAmount: order.receiveAmount,
            receiveSymbol: order.receiveSymbol,
            unit: .receive
        )
        self.sendPrice = SwapQuote.priceRepresentation(
            sendAmount: order.payAmount,
            sendSymbol: order.paySymbol,
            receiveAmount: order.receiveAmount,
            receiveSymbol: order.receiveSymbol,
            unit: .send
        )
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = R.string.localizable.order_details()
        view.backgroundColor = R.color.background_secondary()
        tableView.backgroundColor = R.color.background_secondary()
        tableView.register(R.nib.swapOrderHeaderCell)
        tableView.register(R.nib.multipleAssetChangeCell)
        tableView.register(R.nib.authenticationPreviewInfoCell)
        tableView.register(R.nib.authenticationPreviewCompactInfoCell)
        tableView.register(R.nib.swapOrderIDCell)
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .header:
            1
        case .info:
            InfoRow.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .header:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.swap_order_header, for: indexPath)!
            cell.load(order: order)
            cell.actionView.delegate = self
            return cell
        case .info:
            switch InfoRow(rawValue: indexPath.row)! {
            case .paid:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multiple_asset_change, for: indexPath)!
                cell.reloadData(
                    title: R.string.localizable.swap_order_paid(),
                    iconURL: order.payIconURL,
                    amount: payAmount,
                    amountColor: R.color.market_red()!,
                    network: order.payChainName
                )
                cell.contentTopConstraint.constant = 20
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .receive:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.multiple_asset_change, for: indexPath)!
                let title = switch order.state.knownCase {
                case .pending, .failed, .none:
                    R.string.localizable.estimated_receive()
                case .success, .refunded:
                    R.string.localizable.swap_order_received()
                }
                cell.reloadData(
                    title: title,
                    iconURL: order.receiveIconURL,
                    amount: order.actualReceivingAmount,
                    amountColor: R.color.market_green()!,
                    network: order.receiveChainName
                )
                cell.contentTopConstraint.constant = 10
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .price:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
                cell.captionLabel.text = switch order.state.knownCase {
                case .success:
                    R.string.localizable.price().uppercased()
                case .pending, .failed, .refunded, .none:
                    R.string.localizable.estimated_price().uppercased()
                }
                cell.primaryLabel.text = receivePrice
                cell.secondaryLabel.text = sendPrice
                cell.setPrimaryLabel(usesBoldFont: false)
                cell.trailingContent = nil
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .type:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = R.string.localizable.type().uppercased()
                cell.setContent(order.type.localizedDescription)
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .createdAt:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = R.string.localizable.created().uppercased()
                if let date = order.createdAtDate {
                    cell.setContent(DateFormatter.dateAndTime.string(from: date))
                } else {
                    cell.setContent(order.createdAt)
                }
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .orderID:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.swap_order_id, for: indexPath)!
                cell.contentLabel.text = order.orderID
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
    
}

extension SwapOrderViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension SwapOrderViewController: PillActionView.Delegate {
    
    func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int) {
        switch index {
        case 0:
            if let navigationController {
                var viewControllers = navigationController.viewControllers
                if let index = viewControllers.lastIndex(where: { $0 is MixinSwapViewController }) {
                    viewControllers.removeLast(viewControllers.count - index)
                }
                let swap = MixinSwapViewController(
                    sendAssetID: order.payAssetID,
                    receiveAssetID: order.receiveAssetID
                )
                viewControllers.append(swap)
                navigationController.setViewControllers(viewControllers, animated: true)
            }
        default:
            guard let navigationController else {
                return
            }
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            RouteAPI.markets(id: order.receiveAssetID, queue: .main) { [order, receivePrice] result in
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
                    🏷️ \(R.string.localizable.price()): \(receivePrice)
                    """
                }
                let actions: [AppCardData.V1Content.Action] = [
                    .init(
                        action: "mixin://mixin.one/swap?input=\(order.payAssetID)&output=\(order.receiveAssetID)",
                        color: "#50BD5C",
                        label: R.string.localizable.buy_token(order.receiveSymbol)
                    ),
                    .init(
                        action: "mixin://mixin.one/swap?input=\(order.receiveAssetID)&output=\(order.payAssetID)",
                        color: "#DB454F",
                        label: R.string.localizable.sell_token(order.receiveSymbol)
                    ),
                    .init(
                        action: "mixin://mixin.one/markets/\(order.receiveAssetID)",
                        color: "#3D75E3",
                        label: order.receiveSymbol + " " + R.string.localizable.market()
                    ),
                ]
                let content = AppCardData.V1Content(
                    appID: BotUserID.mixinRoute,
                    cover: nil,
                    title: R.string.localizable.swap() + " " + order.exchangingSymbolRepresentation,
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
        UIPasteboard.general.string = order.orderID
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
