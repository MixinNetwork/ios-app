import UIKit
import MixinServices

final class TransferPreviewViewController: PaymentPreviewViewController {
    
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
        super.init(issues: issues)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let token = operation.token
        
        tableHeaderView.setIcon(token: token)
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_transfer()
        tableHeaderView.subtitleLabel.text = R.string.localizable.review_transfer_hint()
        
        let tokenAmount = CurrencyFormatter.localizedString(from: tokenAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        let fiatMoneyAmount = CurrencyFormatter.localizedString(from: fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
        let fee = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
        var rows: [Row] = [
            .amount(token: tokenAmount, fiatMoney: fiatMoneyAmount, display: amountDisplay),
            .info(caption: .receiverWillReceive, content: tokenAmount),
            .info(caption: .network, content: token.depositNetworkName ?? ""),
            .info(caption: .fee, content: fee),
        ]
        switch operation.destination {
        case let .user(user):
            rows.insert(.receivers([user], threshold: nil), at: 1)
        case let .multisig(threshold, users):
            if let account = LoginManager.shared.account {
                let user = UserItem.createUser(from: account)
                rows.insert(.senders([user], threshold: 1), at: 1)
            }
            rows.insert(.receivers(users, threshold: threshold), at: 2)
        case let .mainnet(address):
            rows.insert(.mainnetReceiver(address), at: 1)
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
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .failure)
                    layoutTableHeaderView(title: R.string.localizable.transfer_failed(),
                                          subtitle: error.localizedDescription, 
                                          style: .destructive)
                    tableView.setContentOffset(.zero, animated: true)
                    switch error {
                    case MixinAPIError.malformedPin, MixinAPIError.incorrectPin:
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
