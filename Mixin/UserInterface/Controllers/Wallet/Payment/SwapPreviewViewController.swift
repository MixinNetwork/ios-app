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
        tableHeaderView.subtitleLabel.text = R.string.localizable.signature_request_from(mixinMessenger)
        
        
        var rows: [Row]
        rows = [
            .swapAssetChange(
                sendToken: sendToken,
                sendAmount: CurrencyFormatter.localizedString(
                    from: -operation.sendAmount,
                    format: .precision,
                    sign: .always,
                    symbol: .custom(sendToken.symbol)
                ),
                receiveToken: receiveToken,
                receiveAmount: CurrencyFormatter.localizedString(
                    from: operation.receiveAmount,
                    format: .precision,
                    sign: .always,
                    symbol: .custom(receiveToken.symbol)
                )
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
            let feeValue = CurrencyFormatter.localizedString(from: fee.token, format: .precision, sign: .never, symbol: nil)
            let feeCost = if fee.fiatMoney >= 0.01 {
                CurrencyFormatter.localizedString(from: fee.fiatMoney, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            } else {
                "<" + CurrencyFormatter.localizedString(from: 0.01, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
            }
            rows.append(.amount(caption: .fee,
                                token: feeValue + " " + destination.feeTokenSymbol,
                                   fiatMoney: feeCost,
                                   display: .byToken,
                                   boldPrimaryAmount: false))
            rows.append(.receivers([destination.displayReceiver], threshold: nil))
            rows.append(.sendingAddress(value: destination.senderAddress.destination, label: nil))
        }
        
        if let memo = operation.memo, !memo.isEmpty {
            rows.append(.info(caption: .memo, content: memo))
        }
        
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        
        layoutTableHeaderView(title: R.string.localizable.sending(),
                                  subtitle: R.string.localizable.signature_request_from(mixinMessenger))
        
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
                    reporter.report(event: .swapSend)
                    
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
