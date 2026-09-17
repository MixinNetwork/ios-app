import UIKit
import MixinServices

final class ReducePerpsPositionMarginPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    private let wallet: Wallet
    private let marketViewModel: PerpetualMarketViewModel
    private let positionViewModel: PerpetualPositionViewModel
    private let reducingMargin: Decimal
    private let onDismissAfterSuccess: (() -> Void)?
    
    private var hasSucceeded = false
    
    init(
        wallet: Wallet,
        marketViewModel: PerpetualMarketViewModel,
        positionViewModel: PerpetualPositionViewModel,
        reducingMargin: Decimal,
        onDismissAfterSuccess: (() -> Void)?,
    ) {
        self.wallet = wallet
        self.marketViewModel = marketViewModel
        self.positionViewModel = positionViewModel
        self.reducingMargin = reducingMargin
        self.onDismissAfterSuccess = onDismissAfterSuccess
        super.init(wallet: wallet, warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setTokenIcon(url: marketViewModel.iconURL)
        tableHeaderView.titleLabel.text = R.string.localizable.perps_confirm_reduce_margin()
        tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixin)
        
        let receivingToken = TokenDAO.shared.tokenItem(
            assetID: positionViewModel.estimatedReceiving.assetID
        )
        
        var rows: [Row] = [
            .perpsPositions([(
                iconURL: marketViewModel.iconURL,
                name: marketViewModel.market.displaySymbol,
                side: positionViewModel.side,
                leverage: nil
            )])
        ]
        if let token = receivingToken {
            let count = CurrencyFormatter.localizedString(
                from: reducingMargin,
                format: .precision,
                sign: .always
            )
            rows.append(.estimatedReceive(token: token, count: count, pnl: nil))
        }
        rows.append(
            .wallet(caption: .receiver, wallet: wallet, threshold: nil)
        )
        reloadData(with: rows)
    }
    
    override func confirm(_ sender: Any) {
        super.confirm(sender)
        reporter.report(event: .tradePerpsReduceMarginPreviewConfirm)
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        if !hasSucceeded {
            reporter.report(event: .tradePerpsReduceMarginPreviewCancel)
        }
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(
            title: R.string.localizable.perps_reducing_margin(),
            subtitle: R.string.localizable.signature_request_from(.mixin)
        )
        replaceTrayView(with: nil, animation: .vertical)
        let positionID = positionViewModel.positionID
        let amount = reducingMargin.formatted(
            MixinToken.transferCanonicalFormatStyle
        )
        Task {
            do {
                try await AccountAPI.verify(pin: pin)
                try await RouteAPI.decreasePerpsMargin(
                    positionID: positionID,
                    amount: amount,
                )
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    hasSucceeded = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(
                        title: R.string.localizable.perps_margin_submitted(),
                        subtitle: R.string.localizable.position_submitted_description(),
                    )
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                    if let onDismissAfterSuccess {
                        onDismiss = onDismissAfterSuccess
                    }
                    reporter.report(event: .tradePerpsReduceMarginEnd)
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
                    layoutTableHeaderView(
                        title: R.string.localizable.perps_reducing_margin_failed(),
                        subtitle: errorDescription,
                        style: .destructive
                    )
                    tableView.setContentOffset(.zero, animated: true)
                    switch error {
                    case MixinAPIResponseError.malformedPin, MixinAPIResponseError.incorrectPin, TIPNode.Error.response(.incorrectPIN), TIPNode.Error.response(.internalServer):
                        loadDoubleButtonTrayView(
                            leftTitle: R.string.localizable.cancel(),
                            leftAction: #selector(close(_:)),
                            rightTitle: R.string.localizable.retry(),
                            rightAction: #selector(confirm(_:)),
                            animation: .vertical
                        )
                    default:
                        loadSingleButtonTrayView(
                            title: R.string.localizable.got_it(),
                            action: #selector(close(_:))
                        )
                    }
                }
            }
        }
    }
    
}
