import UIKit
import MixinServices

final class InvoicePreviewViewController: AuthenticationPreviewViewController {
    
    var manipulateNavigationStackOnFinished = true
    
    private let operation: InvoicePaymentOperation
    private let redirection: URL?
    
    init(
        issues: [PaymentPreconditionIssue],
        operation: InvoicePaymentOperation,
        redirection: URL?
    ) {
        self.operation = operation
        self.redirection = redirection
        super.init(warnings: issues.map(\.description))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setIcon(tokens: operation.transactions.map(\.token))
        tableHeaderView.titleLabel.text = R.string.localizable.batch_transfer_confirmation()
        tableHeaderView.subtitleLabel.text = R.string.localizable.signature_request_from(mixinMessenger)
        
        let totalUSDAmount = operation.transactions.reduce(0) { result, item in
            result + item.token.decimalUSDPrice * item.entry.decimalAmount
        }
        let totalFiatMoneyAmount = CurrencyFormatter.localizedString(
            from: totalUSDAmount * Currency.current.decimalRate,
            format: .fiatMoney,
            sign: .never,
            symbol: .currencySymbol
        )
        var rows: [Row] = [
            .info(caption: .totalAmount, content: totalFiatMoneyAmount),
        ]
        
        let changes = operation.transactions.map { item in
            let amount = CurrencyFormatter.localizedString(
                from: -item.entry.decimalAmount,
                format: .precision,
                sign: .always,
                symbol: .custom(item.token.symbol)
            )
            return (token: item.token, amount: amount)
        }
        rows.append(.assetChanges(changes))
        
        let senderThreshold: Int32?
        switch operation.destination {
        case let .user(user):
            rows.append(.receivers([user], threshold: nil))
            senderThreshold = nil
        case let .multisig(threshold, users):
            rows.append(.receivers(users, threshold: threshold))
            senderThreshold = 1
        case let .mainnet(address):
            rows.append(.mainnetReceiver(address))
            senderThreshold = nil
        }
        if let account = LoginManager.shared.account {
            let user = UserItem.createUser(from: account)
            rows.append(.senders([user], multisigSigners: nil, threshold: senderThreshold))
        }
        
        rows.append(.amount(
            caption: .networkFee,
            token: CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never),
            fiatMoney: CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol),
            display: .byToken,
            boldPrimaryAmount: false
        ))
        
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(title: R.string.localizable.sending_transfer_request(),
                              subtitle: R.string.localizable.transfer_sending_description())
        replaceTrayView(with: nil, animation: .vertical)
        Task {
            do {
                try await operation.start(pin: pin)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(title: R.string.localizable.transfer_success(),
                                          subtitle: R.string.localizable.transfer_sent_description())
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
                            view.style = .info
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
                    layoutTableHeaderView(title: R.string.localizable.transfer_failed(),
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
                } else if viewControllers.last is TransferOutViewController {
                    viewControllers.removeLast()
                }
            }
            navigation.setViewControllers(viewControllers, animated: false)
        case .multisig, .mainnet:
            if viewControllers.last is TransferOutViewController {
                viewControllers.removeLast()
            }
            navigation.setViewControllers(viewControllers, animated: false)
        }
    }
    
}