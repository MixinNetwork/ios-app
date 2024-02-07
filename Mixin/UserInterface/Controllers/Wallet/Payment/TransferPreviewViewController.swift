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
        var rows: [Row] = [
            .amount(token: tokenAmount, fiatMoney: fiatMoneyAmount),
            .info(caption: .receiverWillReceive, content: tokenAmount),
            .info(caption: .network, content: token.depositNetworkName ?? ""),
            .info(caption: .fee, content: "0"),
        ]
        switch operation.destination {
        case let .user(user):
            rows.insert(.receivers([user], threshold: nil), at: 1)
        case let .multisig(threshold, users):
            rows.insert(.receivers(users, threshold: threshold), at: 1)
        case let .mainnet(address):
            rows.insert(.mainnetReceiver(address), at: 1)
        }
        if !operation.memo.isEmpty {
            rows.append(.info(caption: .memo, content: operation.memo))
        }
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(title: R.string.localizable.sending_transfer_request(),
                              subtitle: R.string.localizable.transfer_sending_description())
        replaceTrayView(with: nil, animated: true)
        Task {
            do {
                try await operation.start(pin: pin)
                await MainActor.run {
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(title: R.string.localizable.transfer_success(),
                                          subtitle: R.string.localizable.transfer_sent_description())
                    if redirection == nil {
                        loadFinishedTrayView()
                    } else {
                        loadDialogTrayView(animated: true) { view in
                            view.iconImageView.image = R.image.payment_merchant_success()?.withRenderingMode(.alwaysTemplate)
                            view.titleLabel.text = R.string.localizable.return_to_merchant_description()
                            view.leftButton.setTitle(R.string.localizable.back_to_merchant(), for: .normal)
                            view.leftButton.addTarget(self, action: #selector(gotoMerchant(_:)), for: .touchUpInside)
                            view.rightButton.setTitle(R.string.localizable.stay_in_mixin(), for: .normal)
                            view.rightButton.addTarget(self, action: #selector(finish(_:)), for: .touchUpInside)
                            view.style = .info
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    tableHeaderView.setIcon(progress: .failure)
                    layoutTableHeaderView(title: R.string.localizable.transfer_failed(),
                                          subtitle: error.localizedDescription)
                    switch error {
                    case MixinAPIError.malformedPin, MixinAPIError.incorrectPin:
                        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                 leftAction: #selector(close(_:)),
                                                 rightTitle: R.string.localizable.retry(),
                                                 rightAction: #selector(confirm(_:)),
                                                 animated: true)
                    default:
                        loadSingleButtonTrayView(title: R.string.localizable.got_it(),
                                                 action: #selector(close(_:)))
                    }
                }
            }
        }
    }
    
    override func finish(_ sender: Any) {
        guard manipulateNavigationStackOnFinished else {
            presentingViewController?.dismiss(animated: true)
            return
        }
        let destination = operation.destination
        presentingViewController?.dismiss(animated: true) {
            guard let navigation = UIApplication.homeNavigationController else {
                return
            }
            var viewControllers = navigation.viewControllers
            switch destination {
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
                navigation.setViewControllers(viewControllers, animated: true)
            case .multisig, .mainnet:
                if let lastViewController = viewControllers.last as? ContainerViewController, lastViewController.viewController is TransferOutViewController {
                    viewControllers.removeLast()
                }
                navigation.setViewControllers(viewControllers, animated: true)
            }
        }
    }
    
    @objc private func gotoMerchant(_ sender: Any) {
        guard let redirection = redirection else {
            finish(sender)
            return
        }
        // A non-nil `redirection` doesn't imply `manipulateNavigationStackOnFinished` is false, despite the current state being so.
        // Currently, all merchant payments are invoked via URL, so there's no need to manipulate the navigation stack.
        // There might be issues here if the logic above changes.
        presentingViewController?.dismiss(animated: true) {
            UIApplication.shared.open(redirection)
        }
    }
    
}
