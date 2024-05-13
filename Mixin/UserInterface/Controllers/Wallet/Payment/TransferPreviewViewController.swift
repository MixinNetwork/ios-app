import UIKit
import MixinServices

final class TransferPreviewViewController: AuthenticationPreviewViewController {
    
    var manipulateNavigationStackOnFinished = true
    
    private let operation: TransferPaymentOperation
    private let amountDisplay: AmountIntent
    private let tokenAmount: Decimal
    private let fiatMoneyAmount: Decimal
    private let redirection: URL?
    
    init(
        issues: [PaymentPreconditionIssue],
        operation: TransferPaymentOperation,
        amountDisplay: AmountIntent,
        tokenAmount: Decimal,
        fiatMoneyAmount: Decimal,
        redirection: URL?
    ) {
        self.operation = operation
        self.amountDisplay = amountDisplay
        self.tokenAmount = tokenAmount
        self.fiatMoneyAmount = fiatMoneyAmount
        self.redirection = redirection
        super.init(warnings: issues.map(\.description))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let token = operation.token
        
        if let inscription = operation.inscription {
            tableHeaderView.setIcon { imageView in
                imageView.layer.cornerRadius = 12
                if inscription.contentType.starts(with: "image/"), let url = URL(string: inscription.contentURL) {
                    imageView.sd_setImage(with: url, placeholderImage: nil, context: assetIconContext)
                } else {
                    imageView.backgroundColor = R.color.sticker_button_background_disabled()
                    imageView.image = R.image.inscription_intaglio()
                }
            }
        } else {
            tableHeaderView.setIcon(token: token)
        }
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_transfer()
        tableHeaderView.subtitleLabel.text = R.string.localizable.review_transfer_hint()
        
        var rows: [Row]
        
        let tokenValue = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        let fiatMoneyValue = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        
        if let inscription = operation.inscription {
            rows = [
                .info(caption: .collectible, content: inscription.collectionSequenceRepresentation),
            ]
        } else {
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
        case let .mainnet(address):
            rows.append(.mainnetReceiver(address))
            senderThreshold = nil
        }
        if let account = LoginManager.shared.account {
            let user = UserItem.createUser(from: account)
            rows.append(.senders([user], threshold: senderThreshold))
        }
        
        if operation.inscription == nil {
            rows.append(contentsOf: [
                .amount(caption: .fee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: amountDisplay, boldPrimaryAmount: false),
                .amount(caption: .total, token: tokenValue, fiatMoney: fiatMoneyValue, display: amountDisplay, boldPrimaryAmount: false),
                .info(caption: .network, content: token.depositNetworkName ?? ""),
            ])
        }
        
        if !operation.memo.isEmpty {
            rows.append(.info(caption: .memo, content: operation.memo))
        }
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
                } else if let container = viewControllers.last as? ContainerViewController, container.viewController is TransferOutViewController {
                    viewControllers.removeLast()
                }
            }
            navigation.setViewControllers(viewControllers, animated: false)
        case .multisig, .mainnet:
            if let lastViewController = viewControllers.last as? ContainerViewController, lastViewController.viewController is TransferOutViewController {
                viewControllers.removeLast()
            }
            navigation.setViewControllers(viewControllers, animated: false)
        }
    }
    
}
