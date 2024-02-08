import UIKit
import MixinServices

final class WithdrawPreviewViewController: PaymentPreviewViewController {
    
    var manipulateNavigationStackOnFinished = true
    
    private let operation: WithdrawPaymentOperation
    private let amountDisplay: AmountIntent
    private let withdrawalTokenAmount: Decimal
    private let withdrawalFiatMoneyAmount: Decimal
    private let addressLabel: String?
    
    init(
        issues: [PaymentPreconditionIssue],
        operation: WithdrawPaymentOperation,
        amountDisplay: AmountIntent,
        withdrawalTokenAmount: Decimal,
        withdrawalFiatMoneyAmount: Decimal,
        addressLabel: String?
    ) {
        self.operation = operation
        self.amountDisplay = amountDisplay
        self.withdrawalTokenAmount = withdrawalTokenAmount
        self.withdrawalFiatMoneyAmount = withdrawalFiatMoneyAmount
        self.addressLabel = addressLabel
        super.init(issues: issues)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let token = operation.withdrawalToken
        
        tableHeaderView.setIcon(token: token)
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_withdrawal()
        tableHeaderView.subtitleLabel.text = R.string.localizable.review_withdrawal_hint()
        
        let feeFiatMoneyAmount = operation.feeAmount * operation.feeToken.decimalUSDPrice * Decimal(Currency.current.rate)
        
        let withdrawalTokenValue = CurrencyFormatter.localizedString(from: operation.withdrawalTokenAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        let withdrawalFiatMoneyValue = CurrencyFormatter.localizedString(from: operation.withdrawalFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
        let feeTokenValue = CurrencyFormatter.localizedString(from: operation.feeAmount, format: .precision, sign: .never, symbol: .custom(token.symbol))
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: feeFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currentCurrency)
        let rows: [Row] = [
            .amount(token: withdrawalTokenValue, fiatMoney: withdrawalFiatMoneyValue, display: amountDisplay),
            .address(value: operation.address.fullRepresentation, label: operation.addressLabel),
            .info(caption: .addressWillReceive, content: withdrawalTokenValue),
            .info(caption: .network, content: token.depositNetworkName ?? ""),
            .fee(token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: amountDisplay)
        ]
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(title: R.string.localizable.sending_withdrawal_request(),
                              subtitle: R.string.localizable.withdrawal_sending_description())
        replaceTrayView(with: nil, animation: .vertical)
        Task {
            do {
                try await operation.start(pin: pin)
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(title: R.string.localizable.withdrawal_request_sent(),
                                          subtitle: R.string.localizable.withdrawal_sent_description())
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                    manipulateNavigationStackIfNeeded()
                }
            } catch {
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .failure)
                    layoutTableHeaderView(title: R.string.localizable.withdrawal_failed(),
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
    
    private func manipulateNavigationStackIfNeeded() {
        guard manipulateNavigationStackOnFinished else {
            return
        }
        guard let navigation = UIApplication.homeNavigationController else {
            return
        }
        var viewControllers = navigation.viewControllers
        while (viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController)) {
            if let _ = (viewControllers.last as? ContainerViewController)?.viewController as? TokenViewController {
                break
            }
            viewControllers.removeLast()
        }
        navigation.setViewControllers(viewControllers, animated: false)
    }
    
}
