import UIKit
import MixinServices

final class SwapPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    enum Operation {
        case mixin(TransferPaymentOperation)
        case web3(Web3TransferOperation)
    }
    
    private let mode: Payment.SwapContext.Mode
    private let operation: Operation
    
    private let sendToken: any Token
    private let sendAmount: Decimal
    
    private let receiveToken: any Token
    private let receiveAmount: Decimal
    
    private let receiver: UserItem
    
    init(
        wallet: Wallet, mode: Payment.SwapContext.Mode,
        operation: Operation,
        sendToken: any Token, sendAmount: Decimal,
        receiveToken: any Token, receiveAmount: Decimal,
        receiver: UserItem, warnings: [String]
    ) {
        self.mode = mode
        self.operation = operation
        self.sendToken = sendToken
        self.sendAmount = sendAmount
        self.receiveToken = receiveToken
        self.receiveAmount = receiveAmount
        self.receiver = receiver
        super.init(wallet: wallet, warnings: warnings)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setIcon(sendToken: sendToken, receiveToken: receiveToken)
        tableHeaderView.titleLabel.text = R.string.localizable.swap_confirmation()
        tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixinMessenger)
        
        let orderType = switch mode {
        case .simple:
            R.string.localizable.order_type_swap()
        case .advanced:
            R.string.localizable.order_type_limit()
        }
        
        var rows: [Row]
        rows = [
            .assetChanges(
                estimated: true,
                changes: [
                    StyledAssetChange(
                        token: sendToken,
                        amount: CurrencyFormatter.localizedString(
                            from: -sendAmount,
                            format: .precision,
                            sign: .always,
                            symbol: .custom(sendToken.symbol)
                        ),
                        amountStyle: .plain
                    ),
                    StyledAssetChange(
                        token: receiveToken,
                        amount: CurrencyFormatter.localizedString(
                            from: receiveAmount,
                            format: .precision,
                            sign: .always,
                            symbol: .custom(receiveToken.symbol)
                        ),
                        amountStyle: .income
                    ),
                ]
            ),
            .info(
                caption: .string(R.string.localizable.order_type()),
                content: orderType
            ),
            .doubleLineInfo(
                caption: .price,
                primary: SwapQuote.priceRepresentation(
                    sendAmount: sendAmount,
                    sendSymbol: sendToken.symbol,
                    receiveAmount: receiveAmount,
                    receiveSymbol: receiveToken.symbol,
                    unit: .send
                ),
                secondary: SwapQuote.priceRepresentation(
                    sendAmount: sendAmount,
                    sendSymbol: sendToken.symbol,
                    receiveAmount: receiveAmount,
                    receiveSymbol: receiveToken.symbol,
                    unit: .receive
                )
            ),
        ]
        
        switch mode {
        case .simple:
            break
        case .advanced(let expiry):
            rows.append(
                .info(
                    caption: .string(R.string.localizable.swap_expiry()),
                    content: expiry.localizedName
                )
            )
        }
        
        switch operation {
        case .mixin(let operation):
            let feeTokenValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .precision, sign: .never)
            let feeFiatMoneyValue = CurrencyFormatter.localizedString(from: Decimal(0), format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            rows.append(.amount(caption: .networkFee, token: feeTokenValue, fiatMoney: feeFiatMoneyValue, display: .byToken, boldPrimaryAmount: false))
            rows.append(.receivers([receiver], threshold: nil))
            rows.append(.wallet(caption: .sender, wallet: .privacy, threshold: nil))
            if let memo = operation.extra.plainValue, !memo.isEmpty {
                rows.append(.info(caption: .memo, content: memo))
            }
        case .web3(let operation):
            if let fee = operation.fee {
                var feeValue = CurrencyFormatter.localizedString(
                    from: fee.tokenAmount,
                    format: .precision,
                    sign: .never,
                    symbol: .custom(operation.feeToken.symbol)
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
                rows.append(.amount(
                    caption: .fee,
                    token: feeValue,
                    fiatMoney: feeCost,
                    display: .byToken,
                    boldPrimaryAmount: false
                ))
            }
            rows.append(contentsOf: [
                .receivers([receiver], threshold: nil),
                .address(
                    caption: .sender,
                    address: operation.fromAddress.destination,
                    label: .wallet(.common(operation.wallet))
                ),
            ])
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
        let reportType = switch mode {
        case .simple:
            "swap"
        case .advanced:
            "limit"
        }
        Task {
            do {
                switch operation {
                case .mixin(let operation):
                    try await operation.start(pin: pin)
                    reporter.report(event: .tradeEnd, tags: ["wallet": "main", "type": reportType, "trade_asset_level": sendAmount.reportingAssetLevel])
                case .web3(let operation):
                    try await operation.start(pin: pin)
                    reporter.report(event: .tradeEnd, tags: ["wallet": "web3", "type": reportType, "trade_asset_level": sendAmount.reportingAssetLevel])
                }
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(
                        title: R.string.localizable.sending_success(),
                        subtitle: R.string.localizable.swap_message_success()
                    )
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
