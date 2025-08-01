import UIKit
import MixinServices

class SwapPreviewViewController: AuthenticationPreviewViewController {
    
    private let operation: SwapOperation
    
    init(operation: SwapOperation, warnings: [String]) {
        self.operation = operation
        super.init(warnings: warnings)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let sendToken = operation.sendToken
        let receiveToken = operation.receiveToken
        tableHeaderView.setIcon(sendToken: sendToken, receiveToken: receiveToken)
        tableHeaderView.titleLabel.text = R.string.localizable.swap_confirmation()
        tableHeaderView.subtitleLabel.text = R.string.localizable.signature_request_from(.mixinMessenger)
        
        
        var rows: [Row]
        rows = [
            .assetChanges(
                estimated: true,
                changes: [
                    StyledAssetChange(
                        token: sendToken,
                        amount: CurrencyFormatter.localizedString(
                            from: -operation.sendAmount,
                            format: .precision,
                            sign: .always,
                            symbol: .custom(sendToken.symbol)
                        ),
                        amountStyle: .plain
                    ),
                    StyledAssetChange(
                        token: receiveToken,
                        amount: CurrencyFormatter.localizedString(
                            from: operation.receiveAmount,
                            format: .precision,
                            sign: .always,
                            symbol: .custom(receiveToken.symbol)
                        ),
                        amountStyle: .income
                    ),
                ]
            ),
            .doubleLineInfo(
                caption: .price,
                primary: SwapQuote.priceRepresentation(
                    sendAmount: operation.sendAmount,
                    sendSymbol: sendToken.symbol,
                    receiveAmount: operation.receiveAmount,
                    receiveSymbol: receiveToken.symbol,
                    unit: .send
                ),
                secondary: SwapQuote.priceRepresentation(
                    sendAmount: operation.sendAmount,
                    sendSymbol: sendToken.symbol,
                    receiveAmount: operation.receiveAmount,
                    receiveSymbol: receiveToken.symbol,
                    unit: .receive
                )
            ),
        ]
        
        switch operation.destination {
        case let .mixin(user):
            let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
            let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            rows.append(.amount(caption: .networkFee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: .byToken, boldPrimaryAmount: false))
            rows.append(.receivers([user], threshold: nil))
            if let account = LoginManager.shared.account {
                let user = UserItem.createUser(from: account)
                rows.append(.senders([user], multisigSigners: nil, threshold: nil))
            }
        case let .web3(destination):
            let fee = destination.fee
            var feeValue = CurrencyFormatter.localizedString(
                from: fee.tokenAmount,
                format: .precision,
                sign: .never,
                symbol: .custom(destination.feeTokenSymbol)
            )
            if let fee = fee as? EVMTransferOperation.EVMDisplayFee {
                let feePerGas = CurrencyFormatter.localizedString(
                    from: fee.feePerGas,
                    format: .precision,
                    sign: .never,
                    symbol: .custom("Gwei")
                )
                feeValue.append(" (\(feePerGas))")
            }
            let feeCost = if fee.fiatMoneyAmount >= 0.01 {
                CurrencyFormatter.localizedString(from: fee.fiatMoneyAmount, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            } else {
                "<" + CurrencyFormatter.localizedString(from: 0.01, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            }
            rows.append(contentsOf: [
                .amount(
                    caption: .fee,
                    token: feeValue,
                    fiatMoney: feeCost,
                    display: .byToken,
                    boldPrimaryAmount: false
                ),
                .receivers([destination.displayReceiver], threshold: nil),
                .sendingAddress(value: destination.senderAddress.destination, label: nil),
            ])
        }
        
        if let memo = operation.memo, !memo.isEmpty {
            rows.append(.info(caption: .memo, content: memo))
        }
        
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        
        layoutTableHeaderView(
            title: R.string.localizable.sending(),
            subtitle: R.string.localizable.signature_request_from(.mixinMessenger)
        )
        
        replaceTrayView(with: nil, animation: .vertical)
        Task {
            do {
                try await operation.start(pin: pin)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(title: R.string.localizable.sending_success(),
                                          subtitle: R.string.localizable.swap_message_success())
                    
                    switch operation.destination {
                    case .mixin:
                        reporter.report(event: .tradeEnd, tags: ["wallet": "main", "type": "swap"])
                    case .web3:
                        reporter.report(event: .tradeEnd, tags: ["wallet": "web3", "type": "swap"])
                    }
                    
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                    guard let navigation = UIApplication.homeNavigationController else {
                        return
                    }
                    if let swap = navigation.viewControllers.last as? SwapViewController {
                        swap.prepareForReuse(sender: self)
                    }
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
                    let title = R.string.localizable.swap_failed()
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
}
