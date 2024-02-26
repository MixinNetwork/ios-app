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
        
        let withdrawalToken = operation.withdrawalToken
        let withdrawalTokenAmount = operation.withdrawalTokenAmount
        let feeToken = operation.feeToken
        let feeTokenAmount = operation.feeAmount
        
        tableHeaderView.setIcon(token: withdrawalToken)
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_withdrawal()
        tableHeaderView.subtitleLabel.text = R.string.localizable.review_withdrawal_hint()
        
        let feeFiatMoneyAmount = feeTokenAmount * feeToken.decimalUSDPrice * Decimal(Currency.current.rate)
        let totalFiatMoneyAmount = withdrawalFiatMoneyAmount + feeFiatMoneyAmount
        
        let withdrawalTokenValue = CurrencyFormatter.localizedString(from: withdrawalTokenAmount, format: .precision, sign: .never, symbol: .custom(withdrawalToken.symbol))
        let withdrawalFiatMoneyValue = CurrencyFormatter.localizedString(from: operation.withdrawalFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        let feeTokenValue = CurrencyFormatter.localizedString(from: feeTokenAmount, format: .precision, sign: .never, symbol: .custom(feeToken.symbol))
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: feeFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        let totalFiatMoneyValue = CurrencyFormatter.localizedString(from: totalFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        
        var rows: [Row] = [
            .amount(caption: .amount, token: withdrawalTokenValue, fiatMoney: withdrawalFiatMoneyValue, display: amountDisplay),
            .receivingAddress(value: operation.address.fullRepresentation, label: operation.addressLabel),
        ]
        if let account = LoginManager.shared.account {
            let user = UserItem.createUser(from: account)
            rows.append(.senders([user], threshold: nil))
        }
        rows.append(.fee(token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: amountDisplay))
        if operation.isFeeTokenDifferent {
            let totalTokenValue = "\(withdrawalTokenValue) + \(feeTokenValue)"
            rows.append(.amount(caption: .total, token: totalTokenValue, fiatMoney: totalFiatMoneyValue, display: amountDisplay))
        } else {
            let totalTokenAmount = withdrawalTokenAmount + feeTokenAmount
            let totalTokenValue = CurrencyFormatter.localizedString(from: totalTokenAmount, format: .precision, sign: .never, symbol: .custom(withdrawalToken.symbol))
            rows.append(.amount(caption: .total, token: totalTokenValue, fiatMoney: totalFiatMoneyValue, display: amountDisplay))
        }
        rows.append(.info(caption: .network, content: withdrawalToken.depositNetworkName ?? ""))
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
                let errorDescription = if let error = error as? MixinAPIError, PINVerificationFailureHandler.canHandle(error: error) {
                    await PINVerificationFailureHandler.handle(error: error)
                } else {
                    error.localizedDescription
                }
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .failure)
                    layoutTableHeaderView(title: R.string.localizable.withdrawal_failed(),
                                          subtitle: errorDescription,
                                          style: .destructive)
                    tableView.setContentOffset(.zero, animated: true)
                    switch error {
                    case MixinAPIResponseError.malformedPin, MixinAPIResponseError.incorrectPin:
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
