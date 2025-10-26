import UIKit
import MixinServices

final class WithdrawPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    var manipulateNavigationStackOnFinished = true
    
    private let operation: WithdrawPaymentOperation
    private let amountDisplay: AmountIntent
    
    init(
        issues: [PaymentPreconditionIssue],
        operation: WithdrawPaymentOperation,
        amountDisplay: AmountIntent,
    ) {
        self.operation = operation
        self.amountDisplay = amountDisplay
        super.init(wallet: .privacy, warnings: issues.map(\.description))
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let withdrawalToken = operation.withdrawalToken
        let withdrawalTokenAmount = operation.withdrawalTokenAmount
        let withdrawalFiatMoneyAmount = operation.withdrawalFiatMoneyAmount
        let feeToken = operation.feeToken
        let feeTokenAmount = operation.feeAmount
        
        tableHeaderView.setIcon(token: withdrawalToken)
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_withdrawal()
        tableHeaderView.subtitleTextView.text = R.string.localizable.review_withdrawal_hint()
        
        let feeFiatMoneyAmount = feeTokenAmount * feeToken.decimalUSDPrice * Decimal(Currency.current.rate)
        let totalFiatMoneyAmount = withdrawalFiatMoneyAmount + feeFiatMoneyAmount
        
        let withdrawalTokenValue = CurrencyFormatter.localizedString(from: withdrawalTokenAmount, format: .precision, sign: .never, symbol: .custom(withdrawalToken.symbol))
        let withdrawalFiatMoneyValue = CurrencyFormatter.localizedString(from: operation.withdrawalFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        let feeTokenValue = CurrencyFormatter.localizedString(from: feeTokenAmount, format: .precision, sign: .never, symbol: .custom(feeToken.symbol))
        let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: feeFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        let totalFiatMoneyValue = CurrencyFormatter.localizedString(from: totalFiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        
        var rows: [Row] = [
            .amount(caption: .amount, token: withdrawalTokenValue, fiatMoney: withdrawalFiatMoneyValue, display: amountDisplay, boldPrimaryAmount: true),
        ]
        rows.append(.address(caption: .receiver, address: operation.address.fullRepresentation, label: operation.addressLabel))
        rows.append(.wallet(caption: .sender, wallet: .privacy, threshold: nil))
        let isFeeWaived = operation.addressLabel?.isFeeWaived() ?? false
        let feeRow: Row = if isFeeWaived {
            .waivedFee(
                token: feeTokenValue,
                fiatMoney: feeFiatMoneyValue,
                display: amountDisplay
            )
        } else {
            .amount(
                caption: .fee,
                token: feeTokenValue,
                fiatMoney: feeFiatMoneyValue,
                display: amountDisplay,
                boldPrimaryAmount: false
            )
        }
        rows.append(feeRow)
        if operation.isFeeTokenDifferent {
            let totalTokenValue = "\(withdrawalTokenValue) + \(feeTokenValue)"
            rows.append(.amount(caption: .total, token: totalTokenValue, fiatMoney: totalFiatMoneyValue, display: amountDisplay, boldPrimaryAmount: false))
        } else {
            let totalTokenAmount = withdrawalTokenAmount + feeTokenAmount
            let totalTokenValue = CurrencyFormatter.localizedString(from: totalTokenAmount, format: .precision, sign: .never, symbol: .custom(withdrawalToken.symbol))
            rows.append(.amount(caption: .total, token: totalTokenValue, fiatMoney: totalFiatMoneyValue, display: amountDisplay, boldPrimaryAmount: false))
        }
        rows.append(.info(caption: .network, content: withdrawalToken.depositNetworkName ?? ""))
        reloadData(with: rows)
        reporter.report(event: .sendPreview)
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
                    reporter.report(event: .sendEnd)
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
    
    private func manipulateNavigationStackIfNeeded() {
        guard manipulateNavigationStackOnFinished else {
            return
        }
        guard let navigation = UIApplication.homeNavigationController else {
            return
        }
        var viewControllers = navigation.viewControllers
        while (viewControllers.count > 0 && !(viewControllers.last is HomeTabBarController)) {
            if viewControllers.last is MixinTokenViewController {
                break
            }
            viewControllers.removeLast()
        }
        navigation.setViewControllers(viewControllers, animated: false)
    }
    
}
