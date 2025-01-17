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
    private let receiveAmount: String
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
        self.receiveAmount = CurrencyFormatter.localizedString(
            from: order.receiveAmount,
            format: .precision,
            sign: .always,
            symbol: .custom(order.receiveSymbol)
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
        navigationItem.title = "Order Details"
        view.backgroundColor = R.color.background_secondary()
        tableView.backgroundColor = R.color.background_secondary()
        tableView.register(R.nib.swapOrderHeaderCell)
        tableView.register(R.nib.multipleAssetChangeCell)
        tableView.register(R.nib.authenticationPreviewInfoCell)
        tableView.register(R.nib.authenticationPreviewCompactInfoCell)
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
                    title: "PAID",
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
                cell.reloadData(
                    title: "estimate receive",
                    iconURL: order.receiveIconURL,
                    amount: receiveAmount,
                    amountColor: R.color.market_green()!,
                    network: order.receiveChainName
                )
                cell.contentTopConstraint.constant = 10
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .price:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_info, for: indexPath)!
                cell.captionLabel.text = "Estimated Price".uppercased()
                cell.primaryLabel.text = receivePrice
                cell.secondaryLabel.text = sendPrice
                cell.setPrimaryLabel(usesBoldFont: false)
                cell.trailingContent = nil
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .type:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = "Type".uppercased()
                cell.setContent(order.type?.localizedString ?? "")
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .createdAt:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = "Created".uppercased()
                if let date = order.createdAtDate {
                    cell.setContent(DateFormatter.dateAndTime.string(from: date))
                } else {
                    cell.setContent(order.createdAt)
                }
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                return cell
            case .orderID:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.auth_preview_compact_info, for: indexPath)!
                cell.captionLabel.text = "Order ID".uppercased()
                cell.setContent(order.orderID)
                cell.contentLeadingConstraint.constant = 16
                cell.contentTrailingConstraint.constant = 16
                cell.contentBottomConstraint.constant = 30
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
            let string = "mixin://mixin.one/swap?input=\(order.payAssetID)&output=\(order.receiveAssetID)"
            let message = Message.createMessage(
                messageId: UUID().uuidString.lowercased(),
                conversationId: "",
                userId: myUserId,
                category: MessageCategory.SIGNAL_TEXT.rawValue,
                content: string,
                status: MessageStatus.SENDING.rawValue,
                createdAt: Date().toUTCString()
            )
            let vc = R.storyboard.chat.external_sharing_confirmation()!
            vc.modalPresentationStyle = .custom
            vc.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
            UIApplication.homeContainerViewController?.present(vc, animated: true, completion: nil)
            vc.load(sharingContext: .text(string), message: message, webContext: nil, action: .forward)
        }
    }
    
}
