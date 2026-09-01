import UIKit
import MixinServices

final class OpenPerpetualPositionFailedViewController: WalletIdentifyingAuthenticationPreviewViewController {
    
    private let wallet: Wallet
    private let marketViewModel: PerpetualMarketViewModel
    private let openedPosition: PerpetualPositionItem
    private let leaderPosition: TradeURL.LeaderPosition
    
    init(
        wallet: Wallet,
        viewModel: PerpetualMarketViewModel,
        openedPosition: PerpetualPositionItem,
        leaderPosition: TradeURL.LeaderPosition,
    ) {
        self.wallet = wallet
        self.marketViewModel = viewModel
        self.openedPosition = openedPosition
        self.leaderPosition = leaderPosition
        super.init(wallet: wallet, warnings: [])
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView.setTokenIcon(url: marketViewModel.iconURL)
        tableHeaderView.titleLabel.text = R.string.localizable.position_opening_failed()
        tableHeaderView.subtitleTextView.text = R.string.localizable.error_already_had_open_position()
        
        var rows: [Row] = [
            .perpsPositions([(
                iconURL: marketViewModel.iconURL,
                name: marketViewModel.market.displaySymbol,
                side: leaderPosition.side,
                leverage: nil
            )]),
        ]
        if let leverage = leaderPosition.leverage {
            let multiplier = PerpetualLeverage.stringRepresentation(multiplier: leverage)
            let direction = switch leaderPosition.side {
            case .long:
                R.string.localizable.long_asset(multiplier)
            case .short:
                R.string.localizable.short_asset(multiplier)
            }
            if let margin = leaderPosition.margin {
                let profit = PerpetualChangeSimulation.profit(
                    side: leaderPosition.side,
                    margin: margin,
                    leverageMultiplier: leverage,
                    priceChangePercent: 0.01
                )
                rows.append(.doubleLineInfo(
                    caption: .string(R.string.localizable.direction()),
                    primary: direction,
                    secondary: .plain(profit),
                ))
            } else {
                rows.append(.info(
                    caption: .string(R.string.localizable.direction()),
                    content: direction
                ))
            }
        } else {
            let direction = switch leaderPosition.side {
            case .long:
                R.string.localizable.long()
            case .short:
                R.string.localizable.short()
            }
            rows.append(.info(
                caption: .string(R.string.localizable.direction()),
                content: direction
            ))
        }
        
        if let margin = leaderPosition.margin {
            let amount = CurrencyFormatter.localizedString(
                from: margin,
                format: .precision,
                sign: .never,
                symbol: .custom(marketViewModel.market.quoteSymbol)
            )
            rows.append(.info(
                caption: .string(R.string.localizable.amount()),
                content: amount
            ))
        }
        
        rows.append(.info(
            caption: .string(R.string.localizable.entry_price()),
            content: marketViewModel.price
        ))
        
        rows.append(.wallet(caption: .sender, wallet: wallet, threshold: nil))
        
        reloadData(with: rows)
    }
    
    override func loadInitialTrayView(animated: Bool) {
        let leverageMatches = if let leaderLeverage = leaderPosition.leverage {
            NSDecimalNumber(decimal: leaderLeverage).intValue == openedPosition.leverage
        } else {
            true
        }
        if leaderPosition.side.rawValue == openedPosition.side && leverageMatches {
            loadDoubleButtonTrayView(
                leftTitle: R.string.localizable.cancel(),
                leftAction: #selector(close(_:)),
                rightTitle: R.string.localizable.add_position(),
                rightAction: #selector(addPosition(_:)),
                animation: animated ? .vertical : nil
            )
        } else {
            loadSingleButtonTrayView(
                title: R.string.localizable.cancel(),
                action: #selector(close(_:))
            )
        }
    }
    
    @objc private func addPosition(_ sender: Any) {
        let positionViewModel = PerpetualPositionViewModel(
            wallet: wallet,
            position: openedPosition
        )
        presentingViewController?.dismiss(
            animated: true
        ) { [wallet, marketViewModel, leaderPosition, positionViewModel] in
            guard let margin = positionViewModel.decimalMargin else {
                return
            }
            let addPosition = AddPerpsPositionViewController(
                wallet: wallet,
                marketViewModel: marketViewModel,
                positionViewModel: positionViewModel,
                openedMargin: margin,
                leaderPosition: leaderPosition,
            )
            UIApplication.homeContainerViewController?.present(addPosition, animated: true)
        }
    }
    
}
