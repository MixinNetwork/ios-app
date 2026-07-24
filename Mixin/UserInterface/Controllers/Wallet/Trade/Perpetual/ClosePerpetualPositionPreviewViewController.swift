import UIKit
import MixinServices

final class ClosePerpetualPositionPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    private let viewModels: [PerpetualPositionViewModel]
    private let wallet: Wallet
    
    init?(
        viewModels: [PerpetualPositionViewModel]
    ) {
        guard let wallet = viewModels.first?.wallet else {
            return nil
        }
        let sameWallet = viewModels.allSatisfy { viewModel in
            viewModel.wallet == wallet
        }
        guard sameWallet else {
            return nil
        }
        self.viewModels = viewModels
        self.wallet = wallet
        super.init(wallet: wallet, warnings: [])
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if viewModels.count == 1, let viewModel = viewModels.first {
            tableHeaderView.setTokenIcon(url: viewModel.iconURL)
        } else {
            tableHeaderView.setIcon(tokenIconURLs: viewModels.map(\.iconURL))
        }
        tableHeaderView.titleLabel.text = R.string.localizable.confirm_closing_position()
        tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixin)
        
        var rows: [Row] = []
        
        let positions = viewModels.map { viewModel in
            (
                iconURL: viewModel.iconURL,
                name: viewModel.displaySymbol ?? "",
                side: viewModel.side,
                leverage: viewModel.leverage
            )
        }
        rows.append(.perpsPositions(positions))
        
        let receivings = viewModels.compactMap(\.estimatedReceiving)
        let token = receivings.lazy
            .compactMap { receiving in
                TokenDAO.shared.tokenItem(assetID: receiving.assetID)
            }
            .first
        if let token {
            let totalReceivingAmount = receivings.map(\.receivingAmount).reduce(0, +)
            let totalPnLAmount = receivings.map(\.pnlAmount).reduce(0, +)
            let pnlColor: MarketColor = totalPnLAmount >= 0 ? .rising : .falling
            
            let count = CurrencyFormatter.localizedString(
                from: totalReceivingAmount,
                format: .precision,
                sign: .always,
                symbol: .custom(token.symbol)
            )
            
            let pnl = NSMutableAttributedString(
                string: R.string.localizable.pnl() + ": ",
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: R.color.text_tertiary()!
                ]
            )
            var pnlValue = CurrencyFormatter.localizedString(
                from: totalPnLAmount,
                format: .precision,
                sign: .always,
                symbol: .custom(token.symbol)
            )
            
            let totalWeightedROE: Decimal = viewModels.reduce(0) { result, viewModel in
                if let margin = viewModel.decimalMargin,
                   let roe = viewModel.decimalROE
                {
                    result + margin * roe
                } else {
                    result
                }
            }
            let totalMargin = viewModels.compactMap(\.decimalMargin).reduce(0, +)
            if totalMargin > 0 {
                let aggregatedROE = totalWeightedROE / totalMargin
                let roe = PercentageFormatter.string(
                    from: aggregatedROE,
                    format: .pretty,
                    sign: .never,
                )
                pnlValue += " (" + roe + ")"
            }
            
            pnl.append(NSAttributedString(
                string: pnlValue,
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: pnlColor.uiColor
                ]
            ))
            
            rows.append(.estimatedReceive(token: token, count: count, pnl: pnl))
        }
        rows.append(contentsOf: [
            .wallet(caption: .sender, wallet: wallet, threshold: nil),
        ])
        reloadData(with: rows)
    }
    
    override func confirm(_ sender: Any) {
        super.confirm(sender)
        reporter.report(event: .tradePerpsClosePreviewConfirm)
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        reporter.report(event: .tradePerpsClosePreviewCancel)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderView(
            title: R.string.localizable.closing_position(),
            subtitle: R.string.localizable.signature_request_from(.mixin)
        )
        replaceTrayView(with: nil, animation: .vertical)
        Task {
            do {
                try await AccountAPI.verify(pin: pin)
                let errors = await withTaskGroup(of: Error?.self) { group in
                    for viewModel in viewModels {
                        group.addTask { [positionID=viewModel.positionID] in
                            do {
                                _ = try await RouteAPI.closePerpsOrder(positionID: positionID)
                                return nil
                            } catch {
                                return error
                            }
                        }
                    }
                    var errors: [Error] = []
                    for await error in group {
                        if let error {
                            errors.append(error)
                        }
                    }
                    return errors
                }
                if errors.count == viewModels.count, let firstError = errors.first {
                    throw firstError
                }
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    tableHeaderView.setIcon(progress: .success)
                    layoutTableHeaderView(
                        title: R.string.localizable.position_closed(),
                        subtitle: R.string.localizable.position_closed_description()
                    )
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                    reporter.report(event: .tradePerpsCloseEnd)
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
                    let title = R.string.localizable.position_closing_failed()
                    layoutTableHeaderView(
                        title: title,
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
