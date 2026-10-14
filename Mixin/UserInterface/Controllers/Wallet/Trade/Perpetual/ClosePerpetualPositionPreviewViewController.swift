import UIKit
import MixinServices

final class ClosePerpetualPositionPreviewViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    enum Position {
        case batch([PerpetualPositionViewModel])
        case single(
            viewModel: PerpetualPositionViewModel,
            reducingQuantity: Decimal,
            canonicalFormatStyle: Decimal.FormatStyle,
        )
    }
    
    private let wallet: Wallet
    private let position: Position
    private let onDismissAfterSuccess: (() -> Void)?
    
    private var hasSucceeded = false
    
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
        self.wallet = wallet
        self.position = .batch(viewModels)
        self.onDismissAfterSuccess = nil
        super.init(wallet: wallet, warnings: [])
    }
    
    init(
        reducing viewModel: PerpetualPositionViewModel,
        quantity: Decimal,
        canonicalFormatStyle: Decimal.FormatStyle,
        onDismissAfterSuccess: @escaping () -> Void,
    ) {
        self.wallet = viewModel.wallet
        self.position = .single(
            viewModel: viewModel,
            reducingQuantity: quantity,
            canonicalFormatStyle: canonicalFormatStyle,
        )
        self.onDismissAfterSuccess = onDismissAfterSuccess
        super.init(wallet: viewModel.wallet, warnings: [])
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let viewModels: [PerpetualPositionViewModel] = switch position {
        case .batch(let viewModels):
            viewModels
        case .single(let viewModel, _, _):
            [viewModel]
        }
        if viewModels.count == 1, let viewModel = viewModels.first {
            tableHeaderView.setTokenIcon(url: viewModel.position.iconURL)
            tableHeaderView.titleLabel.text = R.string.localizable.perps_close_position_title(
                viewModel.side.localizedName,
                viewModel.position.tokenSymbol,
            )
        } else {
            tableHeaderView.setIcon(tokenIconURLs: viewModels.map(\.position.iconURL))
            tableHeaderView.titleLabel.text = R.string.localizable.confirm_closing_position()
        }
        tableHeaderView.subtitleTextView.text = R.string.localizable.signature_request_from(.mixin)
        
        var rows: [Row] = []
        
        let positions = viewModels.map { viewModel in
            (
                iconURL: viewModel.position.iconURL,
                name: viewModel.position.displaySymbol ?? "",
                side: viewModel.side,
                leverage: viewModel.leverage
            )
        }
        rows.append(.perpsPositions(positions))
        
        switch position {
        case let .single(viewModel, quantity, _):
            let position = viewModel.position
            let proportion = quantity / viewModel.decimalQuantity
            let margin = viewModel.decimalMargin + position.decimalUnrealizedPnL
            
            let receivingAmount = {
                var amount = margin
                if let fee = position.decimalEstimatedCloseFee {
                    amount -= fee
                }
                return amount * proportion
            }()
            rows.append(.info(
                caption: .string(R.string.localizable.estimated_receive()),
                content: CurrencyFormatter.localizedString(
                    from: receivingAmount,
                    format: .precision,
                    sign: .never,
                    symbol: .dollarSign,
                ),
                action: nil,
            ))
            
            rows.append(.doubleLineInfo(
                caption: .string(R.string.localizable.margin()),
                primary: CurrencyFormatter.localizedString(
                    from: margin * proportion,
                    format: .precision,
                    sign: .never,
                    symbol: .dollarSign,
                ),
                secondary: .attributed({
                    let pnl = NSMutableAttributedString(
                        string: R.string.localizable.perps_include_pnl() + " ",
                        attributes: [
                            .font: UIFont.preferredFont(forTextStyle: .caption1),
                            .foregroundColor: R.color.text_tertiary()!,
                        ]
                    )
                    pnl.append(NSAttributedString(
                        string: CurrencyFormatter.localizedString(
                            from: position.decimalUnrealizedPnL * proportion,
                            format: .precision,
                            sign: .always,
                            symbol: .dollarSign,
                        ),
                        attributes: [.foregroundColor: viewModel.pnlColor.uiColor]
                    ))
                    return pnl
                }())
            ))
            
            if let fee = viewModel.position.decimalEstimatedCloseFee {
                let fee = (fee * proportion).formatted(PerpetualOrder.feeFormatStyle)
                rows.append(.info(
                    caption: .string(R.string.localizable.estimated_fee()),
                    content: fee,
                    action: { [weak self] in
                        self?.introduceFee()
                    },
                ))
            }
        case .batch(let viewModels):
            var totalPnL: Decimal = 0
            var totalMargin: Decimal = 0
            var totalFee: Decimal = 0
            var totalReceivingAmount: Decimal = 0
            for viewModel in viewModels {
                let fee = viewModel.position.decimalEstimatedCloseFee ?? 0
                let pnl = max(
                    -(viewModel.decimalMargin - fee),
                    viewModel.position.decimalUnrealizedPnL,
                )
                let margin = viewModel.decimalMargin + pnl
                totalPnL += pnl
                totalMargin += margin
                totalFee += fee
                totalReceivingAmount += max(0, margin - fee)
            }
            let pnlColor: MarketColor = totalPnL >= 0 ? .rising : .falling
            
            rows.append(.info(
                caption: .string(R.string.localizable.estimated_receive()),
                content: CurrencyFormatter.localizedString(
                    from: totalReceivingAmount,
                    format: .precision,
                    sign: .never,
                    symbol: .dollarSign,
                ),
                action: nil,
            ))
            
            let pnl = NSMutableAttributedString(
                string: R.string.localizable.perps_include_pnl() + " ",
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .caption1),
                    .foregroundColor: R.color.text_tertiary()!,
                ]
            )
            pnl.append(NSAttributedString(
                string: CurrencyFormatter.localizedString(
                    from: totalPnL,
                    format: .precision,
                    sign: .always,
                    symbol: .dollarSign,
                ),
                attributes: [.foregroundColor: pnlColor.uiColor]
            ))
            
            rows.append(.doubleLineInfo(
                caption: .string(R.string.localizable.margin()),
                primary: CurrencyFormatter.localizedString(
                    from: totalMargin,
                    format: .precision,
                    sign: .never,
                    symbol: .dollarSign,
                ),
                secondary: .attributed(pnl)
            ))
            
            rows.append(.info(
                caption: .string(R.string.localizable.estimated_fee()),
                content: totalFee.formatted(PerpetualOrder.feeFormatStyle),
                action: { [weak self] in
                    self?.introduceFee()
                },
            ))
        }
        
        rows.append(contentsOf: [
            .wallet(caption: .receiver, wallet: wallet, threshold: nil),
        ])
        reloadData(with: rows)
    }
    
    override func confirm(_ sender: Any) {
        super.confirm(sender)
        switch position {
        case .batch:
            reporter.report(event: .tradePerpsClosePreviewConfirm)
        case .single:
            reporter.report(event: .tradePerpsReducePositionPreviewConfirm)
        }
    }
    
    override func close(_ sender: Any) {
        super.close(sender)
        if !hasSucceeded {
            switch position {
            case .batch:
                reporter.report(event: .tradePerpsClosePreviewCancel)
            case .single:
                reporter.report(event: .tradePerpsReducePositionPreviewCancel)
            }
        }
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
                switch position {
                case .batch(let viewModels):
                    let errors = await withTaskGroup(of: Error?.self) { group in
                        for viewModel in viewModels {
                            let positionID = viewModel.position.positionID
                            let quantity = viewModel.position.quantity
                            group.addTask {
                                do {
                                    _ = try await RouteAPI.closePerpsOrder(
                                        positionID: positionID,
                                        quantity: quantity,
                                    )
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
                case let .single(viewModel, reducingQuantity, canonicalFormatStyle):
                    _ = try await RouteAPI.closePerpsOrder(
                        positionID: viewModel.position.positionID,
                        quantity: reducingQuantity.formatted(canonicalFormatStyle),
                    )
                }
                UIDevice.current.playPaymentSuccess()
                await MainActor.run {
                    canDismissInteractively = true
                    hasSucceeded = true
                    tableHeaderView.setIcon(progress: .success)
                    switch position {
                    case .batch:
                        layoutTableHeaderView(
                            title: R.string.localizable.position_closed(),
                            subtitle: R.string.localizable.position_closed_description()
                        )
                    case .single:
                        layoutTableHeaderView(
                            title: R.string.localizable.perps_close_submitted(),
                            subtitle: R.string.localizable.position_submitted_description()
                        )
                    }
                    tableView.setContentOffset(.zero, animated: true)
                    loadFinishedTrayView()
                    switch position {
                    case .batch:
                        reporter.report(event: .tradePerpsCloseEnd)
                    case .single:
                        onDismiss = onDismissAfterSuccess
                        reporter.report(event: .tradePerpsReducePositionEnd)
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
    
    private func introduceFee() {
        let manual = PerpsManual.viewController(initialPage: .tradingFee)
        present(manual, animated: true)
        let source = switch position {
        case .batch:
            "perps_close_preview_fee"
        case .single:
            "perps_reduce_position_preview_fee"
        }
        reporter.report(event: .tradePerpsGuide, tags: ["source": source])
    }
    
}
