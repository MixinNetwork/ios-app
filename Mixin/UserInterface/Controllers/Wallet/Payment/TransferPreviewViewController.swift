import UIKit
import MixinServices

final class TransferPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    var manipulateNavigationStackOnFinished = true
    
    private let operation: TransferPaymentOperation
    private let amountDisplay: AmountIntent
    private let redirection: URL?
    
    private var context: Payment.Context? {
        switch operation.behavior {
        case .transfer, .consolidation:
            nil
        case .inscription(let context):
                .inscription(context)
        case .swap(let context):
                .swap(context)
        }
    }
    
    init(
        issues: [PaymentPreconditionIssue],
        operation: TransferPaymentOperation,
        amountDisplay: AmountIntent,
        redirection: URL?
    ) {
        self.operation = operation
        self.amountDisplay = amountDisplay
        self.redirection = redirection
        super.init(wallet: .privacy, warnings: issues.map(\.description))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let token = operation.token
        
        switch operation.behavior {
        case .transfer, .consolidation:
            tableHeaderView.setIcon(token: token)
        case .inscription(let context):
            switch context.item.inscriptionContent {
            case let .image(url):
                tableHeaderView.setIcon { imageView in
                    imageView.layer.cornerRadius = 12
                    imageView.sd_setImage(with: url, placeholderImage: nil)
                }
            case let .text(collectionIconURL, textContentURL):
                tableHeaderView.setIcon(collectionIconURL: collectionIconURL, textContentURL: textContentURL)
            case .none:
                tableHeaderView.setIcon { imageView in
                    imageView.layer.cornerRadius = 12
                    imageView.backgroundColor = R.color.sticker_button_background_disabled()
                    imageView.image = R.image.inscription_intaglio()
                }
            }
        case .swap(let context):
            tableHeaderView.setIcon(sendToken: token, receiveToken: context.receiveToken)
        }
        
        switch context {
        case .swap:
            break
        case .inscription(let context):
            switch context.operation {
            case .transfer:
                tableHeaderView.titleLabel.text = R.string.localizable.confirm_transfer()
                tableHeaderView.subtitleTextView.text = R.string.localizable.review_transfer_hint()
            case .release:
                tableHeaderView.titleLabel.text = R.string.localizable.collectible_release_confirmation()
                tableHeaderView.subtitleTextView.text = R.string.localizable.collectible_release_hint()
            }
        case nil:
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_transfer()
            tableHeaderView.subtitleTextView.text = R.string.localizable.review_transfer_hint()
        }
        
        var rows: [Row]
        
        let tokenAmount: Decimal = switch context {
        case .inscription(let context):
            switch context.operation {
            case .transfer:
                operation.amount
            case .release:
                context.outputAmount
            }
        case .swap, .none:
            operation.amount
        }
        let tokenValue = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        let fiatMoneyAmount = tokenAmount * operation.token.decimalUSDPrice * Currency.current.decimalRate
        let fiatMoneyValue = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        
        switch context {
        case .swap:
            rows = []
        case .inscription(let context):
            rows = [
                .boldInfo(caption: .collectible, content: context.item.collectionSequenceRepresentation),
            ]
            if case .release = context.operation {
                rows.append(.tokenAmount(token: token, tokenAmount: tokenValue, fiatMoneyAmount: fiatMoneyValue))
            }
        case .none:
            rows = [
                .amount(caption: .amount, token: tokenValue, fiatMoney: fiatMoneyValue, display: amountDisplay, boldPrimaryAmount: true),
            ]
        }
        
        let senderThreshold: Int32?
        switch operation.destination {
        case let .user(user):
            rows.append(.receivers([user], threshold: nil))
            senderThreshold = nil
        case let .multisig(threshold, users):
            rows.append(.receivers(users, threshold: threshold))
            senderThreshold = 1
        case let .mainnet(_, address):
            rows.append(.mainnetReceiver(address))
            senderThreshold = nil
        }
        rows.append(.wallet(caption: .sender, wallet: .privacy, threshold: senderThreshold))
        
        switch context {
        case .swap:
            break
        case .inscription(let context):
            switch context.operation {
            case .transfer:
                break
            case .release:
                rows.append(.info(caption: .fee, content: feeTokenValue))
            }
        case .none:
            rows.append(contentsOf: [
                .amount(caption: .fee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: amountDisplay, boldPrimaryAmount: false),
                .amount(caption: .total, token: tokenValue, fiatMoney: fiatMoneyValue, display: amountDisplay, boldPrimaryAmount: false),
                .info(caption: .network, content: token.depositNetworkName ?? ""),
            ])
        }
        
        if let memo = operation.extra.plainValue, !memo.isEmpty {
            rows.append(.info(caption: .memo, content: memo))
        }
        reloadData(with: rows)
        reporter.report(event: .sendPreview)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        switch context {
        case .swap:
           break
        case .inscription(let context):
            switch context.operation {
            case .transfer:
                layoutTableHeaderView(title: R.string.localizable.sending_transfer_request(),
                                      subtitle: R.string.localizable.transfer_sending_description())
            case .release:
                layoutTableHeaderView(title: R.string.localizable.collectible_releasing(),
                                      subtitle: R.string.localizable.collectible_releasing_description())
            }
        case .none:
            layoutTableHeaderView(title: R.string.localizable.sending_transfer_request(),
                                  subtitle: R.string.localizable.transfer_sending_description())
        }
        replaceTrayView(with: nil, animation: .vertical)
        Task {
            do {
                try await operation.start(pin: pin)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    switch context {
                    case .swap:
                        reporter.report(event: .tradeEnd, tags: ["wallet": "main", "type": "swap", "trade_asset_level": operation.amount.reportingAssetLevel])
                    case .inscription(let context):
                        switch context.operation {
                        case .transfer:
                            layoutTableHeaderView(title: R.string.localizable.transfer_success(),
                                                  subtitle: R.string.localizable.transfer_sent_description())
                        case .release:
                            layoutTableHeaderView(title: R.string.localizable.collectible_release_success(),
                                                  subtitle: R.string.localizable.collectible_released_description())
                        }
                    case .none:
                        reporter.report(event: .sendEnd)
                        layoutTableHeaderView(title: R.string.localizable.transfer_success(),
                                              subtitle: R.string.localizable.transfer_sent_description())
                    }
                    tableView.setContentOffset(.zero, animated: true)
                    if redirection == nil {
                        loadFinishedTrayView()
                    } else {
                        loadDialogTrayView(animation: .vertical) { view in
                            view.iconImageView.image = R.image.payment_merchant_success()?.withRenderingMode(.alwaysTemplate)
                            view.titleLabel.text = R.string.localizable.return_to_merchant_description()
                            view.leftButton.setTitle(R.string.localizable.back_to_merchant(), for: .normal)
                            view.leftButton.addTarget(self, action: #selector(gotoMerchant(_:)), for: .touchUpInside)
                            view.rightButton.setTitle(R.string.localizable.stay_in_mixin(), for: .normal)
                            view.rightButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
                            view.style = .gray
                        }
                    }
                    manipulateNavigationStackIfNeeded()
                }
            } catch {
                let errorDescription = if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                    await PINVerificationFailureHandler.handle(error: error)
                } else {
                    error.localizedDescription
                }
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .failure)
                    let title = switch context {
                    case .swap:
                        R.string.localizable.swap_failed()
                    case .inscription(let context):
                        switch context.operation {
                        case .transfer:
                            R.string.localizable.transfer_failed()
                        case .release:
                            R.string.localizable.collectible_release_failed()
                        }
                    case .none:
                        R.string.localizable.transfer_failed()
                    }
                    layoutTableHeaderView(title: title,
                                          subtitle: errorDescription,
                                          style: .destructive)
                    tableView.setContentOffset(.zero, animated: true)
                    switch error {
                    case MixinAPIResponseError.malformedPin, MixinAPIResponseError.incorrectPin, TIPNode.Error.response(.incorrectPIN), TIPNode.Error.response(.internalServer):
                        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                 leftAction: #selector(close(_:)),
                                                 rightTitle: R.string.localizable.retry(),
                                                 rightAction: #selector(confirm(_:)),
                                                 animation: .vertical)
                    default:
                        loadSingleButtonTrayView(title: R.string.localizable.got_it(),
                                                 action: #selector(close(_:)))
                    }
                }
            }
        }
    }
    
    @objc private func gotoMerchant(_ sender: Any) {
        guard let redirection = redirection else {
            close(sender)
            return
        }
        presentingViewController?.dismiss(animated: true) {
            UIApplication.shared.open(redirection)
        }
    }
    
    private func manipulateNavigationStackIfNeeded() {
        guard manipulateNavigationStackOnFinished else {
            return
        }
        guard let navigation = UIApplication.homeNavigationController else {
            return
        }
        var viewControllers = navigation.viewControllers
        
        func manipulateTransferFinished() {
            switch operation.destination {
            case let .user(opponent):
                if viewControllers.lazy.compactMap({ $0 as? ConversationViewController }).first?.dataSource.ownerUser?.userId == opponent.userId {
                    while (viewControllers.count > 0 && !(viewControllers.last is ConversationViewController)) {
                        viewControllers.removeLast()
                    }
                } else {
                    if opponent.isCreatedByMessenger {
                        while (viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController)) {
                            viewControllers.removeLast()
                        }
                        viewControllers.append(ConversationViewController.instance(ownerUser: opponent))
                    } else if viewControllers.last is TransferInputAmountViewController {
                        viewControllers.removeLast()
                    }
                }
                navigation.setViewControllers(viewControllers, animated: false)
            case .multisig, .mainnet:
                if viewControllers.last is TransferInputAmountViewController {
                    viewControllers.removeLast()
                }
                navigation.setViewControllers(viewControllers, animated: false)
            }
        }
        
        switch context {
        case .swap:
            break
        case .inscription(let context):
            switch context.operation {
            case .transfer:
                manipulateTransferFinished()
            case .release:
                if let preview = viewControllers.last as? InscriptionViewController, preview.inscriptionHash == context.item.inscriptionHash {
                    viewControllers.removeLast()
                    navigation.setViewControllers(viewControllers, animated: false)
                } else {
                    return
                }
            }
        case .none:
            manipulateTransferFinished()
        }
    }
    
}
