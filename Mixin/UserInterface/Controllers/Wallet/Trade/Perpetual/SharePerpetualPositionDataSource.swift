import Foundation
import MixinServices

struct SharePerpetualPositionDataSource {
    
    enum TrailingPrice {
        case closePrice(String)
        case currentPrice(String)
    }
    
    let title: String
    let iconURL: URL?
    let change: String
    let pnlColor: MarketColor
    let operation: String
    let leverage: String
    let entryPrice: String
    let trailingPrice: TrailingPrice?
    
    init(viewModel: PerpetualPositionViewModel, latestPrice: Decimal?) {
        self.title = viewModel.directionWithSymbol
        self.iconURL = viewModel.iconURL
        self.change = viewModel.roeWithSign ?? ""
        self.pnlColor = viewModel.pnlColor
        self.operation = viewModel.directionWithSymbol
        self.leverage = viewModel.leverage
        self.entryPrice = viewModel.entryPrice
        self.trailingPrice = if let latestPrice {
            .currentPrice(latestPrice.formatted(viewModel.priceFormatStyle))
        } else {
            .none
        }
    }
    
    init(
        viewModel: PerpetualActivityViewModel,
        pnl: PerpetualActivityViewModel.PnL,
        closePrice: String,
    ) {
        self.title = viewModel.directionWithSymbol
        self.iconURL = viewModel.iconURL
        self.change = pnl.percentage
        self.pnlColor = pnl.color
        self.operation = viewModel.directionWithSymbol
        self.leverage = viewModel.leverage
        self.entryPrice = viewModel.entryPrice
        self.trailingPrice = .closePrice(closePrice)
    }
    
    
}
