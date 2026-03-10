import UIKit
import MixinServices

final class OpenPerpetualPositionPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    private let context: Payment.PerpsContext
    private let operation: TransferPaymentOperation
    
    init(
        context: Payment.PerpsContext,
        operation: TransferPaymentOperation,
        warnings: [String]
    ) {
        self.context = context
        self.operation = operation
        super.init(wallet: context.wallet, warnings: warnings)
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setTokenIcon(url: context.viewModel.iconURL)
        tableHeaderView.titleLabel.text = "确认开仓"
        tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixin)
        
        let multiplier = PerpetualLeverage.stringRepresentation(
            multiplier: context.leverageMultiplier
        )
        let direction = switch context.side {
        case .long:
            R.string.localizable.long_asset(multiplier)
        case .short:
            R.string.localizable.short_asset(multiplier)
        }
        let profit = PerpetualChangeSimulation.profit(
            side: context.side,
            margin: operation.amount,
            leverageMultiplier: context.leverageMultiplier,
            priceChangePercent: 0.01
        )
        let amount = CurrencyFormatter.localizedString(
            from: operation.amount,
            format: .precision,
            sign: .never,
            symbol: .custom(operation.token.symbol)
        )
        let liquidationPrice = PerpetualChangeSimulation.liquidationPrice(
            side: context.side,
            entryPrice: context.viewModel.decimalPrice,
            leverageMultiplier: context.leverageMultiplier
        )
        let liquidation = PerpetualChangeSimulation.liquidation(
            side: context.side,
            margin: operation.amount,
            leverageMultiplier: context.leverageMultiplier
        )
        var rows: [Row]
        rows = [
            .perpsProduct(
                iconURL: context.viewModel.iconURL,
                name: context.viewModel.product
            ),
            .doubleLineInfo(
                caption: .string("Direction"),
                primary: direction,
                secondary: profit,
            ),
            .info(caption: .string("Amount (Isolated)"), content: amount),
            .info(caption: .string("Entry Price"), content: context.viewModel.price),
            .doubleLineInfo(
                caption: .string("Estimated Liquidation Price"),
                primary: liquidationPrice,
                secondary: liquidation
            ),
        ]
        switch operation.destination {
        case let .user(item):
            rows.append(.receivers([item], threshold: nil))
        default:
            break
        }
        rows.append(.wallet(caption: .sender, wallet: context.wallet, threshold: nil))
        if let memo = operation.extra.plainValue {
            rows.append(.info(caption: .memo, content: memo))
        }
        reloadData(with: rows)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(
            title: "Opening Position",
            subtitle: R.string.localizable.signature_request_from(.mixin)
        )
        replaceTrayView(with: nil, animation: .vertical)
        Task {
            do {
                try await operation.start(pin: pin)
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(
                        title: "Position Opened",
                        subtitle: "您的开仓已成功。"
                    )
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                    if let navigationController = UIApplication.homeNavigationController {
                        var viewControllers = navigationController.viewControllers
                        if viewControllers.last is OpenPerpetualPositionViewController {
                            viewControllers.removeLast()
                        }
                        if viewControllers.last is PerpetualMarketViewController {
                            viewControllers.removeLast()
                        }
                        navigationController.setViewControllers(viewControllers, animated: false)
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
