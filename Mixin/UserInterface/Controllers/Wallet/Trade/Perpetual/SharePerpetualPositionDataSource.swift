import Foundation
import MixinServices

struct SharePerpetualPositionDataSource {
    
    enum TrailingPrice {
        case closePrice(String)
        case currentPrice(String)
    }
    
    let title: String
    let iconURL: URL?
    let pnl: String
    let roe: String
    let color: MarketColor
    let operation: String
    let leverage: String
    let entryPrice: String
    let trailingPrice: TrailingPrice?
    
    let marketID: String
    let tokenSymbol: String?
    let displaySymbol: String?
    let side: String
    let leverageMultiplier: Int
    
    init(viewModel: PerpetualPositionViewModel, latestPrice: Decimal?) {
        self.title = viewModel.directionWithSymbol
        self.iconURL = viewModel.iconURL
        self.pnl = viewModel.pnl
        self.roe = viewModel.roeWithSign ?? ""
        self.color = viewModel.pnlColor
        self.operation = viewModel.directionWithSymbol
        self.leverage = viewModel.leverage
        self.entryPrice = viewModel.entryPrice
        self.trailingPrice = if let latestPrice {
            .currentPrice(latestPrice.formatted(viewModel.priceFormatStyle))
        } else {
            .none
        }
        self.marketID = viewModel.marketID
        self.tokenSymbol = viewModel.tokenSymbol
        self.displaySymbol = viewModel.displaySymbol
        self.side = viewModel.side.localizedName
        self.leverageMultiplier = viewModel.leverageMultiplier
    }
    
    init(
        viewModel: PerpetualActivityViewModel,
        pnl: PerpetualActivityViewModel.PnL,
        closePrice: String,
    ) {
        self.title = viewModel.directionWithSymbol
        self.iconURL = viewModel.iconURL
        self.pnl = pnl.receivingAmount
        self.roe = pnl.percentage
        self.color = pnl.color
        self.operation = viewModel.directionWithSymbol
        self.leverage = viewModel.leverage
        self.entryPrice = viewModel.entryPrice
        self.trailingPrice = .closePrice(closePrice)
        self.marketID = viewModel.marketID
        self.tokenSymbol = viewModel.tokenSymbol
        self.displaySymbol = viewModel.displaySymbol
        self.side = viewModel.side.localizedName
        self.leverageMultiplier = viewModel.leverageMultiplier
    }
    
}
