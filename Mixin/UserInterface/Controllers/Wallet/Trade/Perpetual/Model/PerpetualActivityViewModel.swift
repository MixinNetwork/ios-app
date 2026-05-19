import Foundation
import MixinServices

struct PerpetualActivityViewModel {
    
    struct PnL {
        let abbreviated: String
        let precised: String
        let percentage: String
        let color: MarketColor
    }
    
    enum State {
        case opened
        case closed(pnl: PnL, closePrice: String)
    }
    
    enum Action {
        
        case viewMarket
        case tradeAgain
        case share
        
        func asPillAction() -> PillActionView.Action {
            switch self {
            case .viewMarket:
                    .init(title: R.string.localizable.view_perps_market())
            case .tradeAgain:
                    .init(title: R.string.localizable.trade_again())
            case .share:
                    .init(title: R.string.localizable.share())
            }
        }
        
    }
    
    let wallet: Wallet
    let marketID: String
    let positionID: String
    let state: State
    let actions: [Action]
    let side: PerpetualOrderSide
    let iconURL: URL?
    let directionWithSymbol: String
    let leverage: String
    let displaySymbol: String?
    let quantity: String
    let tokenSymbol: String?
    let orderValueInToken: String
    let entryPrice: String
    let date: String
    let priceFormatStyle: Decimal.FormatStyle.Currency
    let offset: String
    
    init?(wallet: Wallet, order: PerpetualOrderItem) {
        let side = PerpetualOrderSide(rawValue: order.side) ?? .short
        let quantity = abs(Decimal(string: order.quantity, locale: .enUSPOSIX) ?? 0)
        let entryPrice = Decimal(string: order.entryPrice, locale: .enUSPOSIX)
        let leverage = PerpetualLeverage.stringRepresentation(multiplier: order.leverage)
        
        self.wallet = wallet
        self.marketID = order.marketID
        self.positionID = order.positionID
        switch order.orderType.knownCase {
        case .open, .increasePosition:
            self.state = .opened
            self.actions = [.viewMarket, .share]
        case .close:
            let decimalClosePrice = Decimal(string: order.closePrice, locale: .enUSPOSIX)
            let realizedPnL = Decimal(string: order.realizedPnL, locale: .enUSPOSIX) ?? 0
            let roe = Decimal(string: order.roe, locale: .enUSPOSIX) ?? 0
            let pnl = PnL(
                abbreviated: CurrencyFormatter.localizedString(
                    from: realizedPnL * Currency.current.decimalRate,
                    format: .fiatMoneyPretty,
                    sign: .always,
                    symbol: .currencySymbol
                ),
                precised: CurrencyFormatter.localizedString(
                    from: realizedPnL * Currency.current.decimalRate,
                    format: .fiatMoneyPrecision,
                    sign: .always,
                    symbol: .currencySymbol
                ),
                percentage: PercentageFormatter.string(
                    from: roe,
                    format: .pretty,
                    sign: .always,
                    options: .keepOneFractionDigitForZero
                ),
                color: realizedPnL >= 0 ? .rising : .falling
            )
            let localizedClosePrice = decimalClosePrice?.formatted(order.priceFormatStyle)
            self.state = .closed(
                pnl: pnl,
                closePrice: localizedClosePrice ?? order.closePrice,
            )
            self.actions = [.tradeAgain, .share]
        default:
            assertionFailure("Unknown order type")
            return nil
        }
        self.side = side
        self.iconURL = order.iconURL
        switch PerpetualOrderSide(rawValue: order.side) {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(order.tokenSymbol)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(order.tokenSymbol)
        default:
            self.directionWithSymbol = "\(order.side) \(order.tokenSymbol)"
        }
        self.leverage = leverage
        self.displaySymbol = order.displaySymbol
        self.quantity = CurrencyFormatter.localizedString(
            from: quantity,
            format: .precision,
            sign: .never,
        )
        self.tokenSymbol = order.tokenSymbol
        self.orderValueInToken = CurrencyFormatter.localizedString(
            from: quantity,
            format: .precision,
            sign: .never,
            symbol: .custom(order.tokenSymbol)
        )
        self.entryPrice = if let entryPrice {
            entryPrice.formatted(order.priceFormatStyle)
        } else {
            order.entryPrice
        }
        self.date = if let date = DateFormatter.iso8601Full.date(from: order.updatedAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            order.updatedAt
        }
        self.priceFormatStyle = order.priceFormatStyle
        self.offset = order.updatedAt
    }
    
}
