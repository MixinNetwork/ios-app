import Foundation
import MixinServices

struct PerpetualPositionViewModel {
    
    enum Action {
        
        case tradeAgain
        case close
        case share
        
        func asPillAction() -> PillActionView.Action {
            switch self {
            case .tradeAgain:
                    .init(title: R.string.localizable.trade_again())
            case .close:
                    .init(title: R.string.localizable.close_position(), style: .vibrant)
            case .share:
                    .init(title: R.string.localizable.share())
            }
        }
        
    }
    
    enum Leverage {
        case long(String)
        case short(String)
    }
    
    let wallet: Wallet
    let positionID: String
    let state: PerpetualPositionType
    let side: PerpetualOrderSide
    let iconURL: URL?
    let directionWithSymbol: String
    let leverage: Leverage
    let pnl: String
    let pnlAmount: String
    let pnlColor: MarketColor
    let actions: [Action]
    let displaySymbol: String?
    let orderValueInToken: String
    let orderValueInFiatMoney: String
    let entryPrice: String
    let date: String
    
    // Only available for open positions
    let liquidationPrice: String?
    
    // Only available for closed positions
    let closePrice: String?
    let closedAt: String?
    
    init(wallet: Wallet, position: PerpetualPositionItem) {
        let pnl = Decimal(string: position.unrealizedPnL, locale: .enUSPOSIX) ?? 0
        let decimalEntryPrice = Decimal(string: position.entryPrice, locale: .enUSPOSIX)
        let decimalMargin = Decimal(string: position.margin, locale: .enUSPOSIX)
        let orderValueInUSD: Decimal? = if let decimalMargin {
            decimalMargin * Decimal(position.leverage)
        } else {
            nil
        }
        let orderValueInToken: Decimal? = if let decimalEntryPrice, let orderValueInUSD {
            orderValueInUSD / decimalEntryPrice
        } else {
            nil
        }
        let multiplier = PerpetualLeverage.stringRepresentation(multiplier: position.leverage)
        let side = PerpetualOrderSide(rawValue: position.side) ?? .short
        
        self.wallet = wallet
        self.positionID = position.positionID
        self.state = .open
        self.side = side
        self.iconURL = position.iconURL
        switch side {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(position.tokenSymbol)
            self.leverage = .long(multiplier)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(position.tokenSymbol)
            self.leverage = .short(multiplier)
        }
        self.pnl = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .precision,
            sign: .always,
            symbol: .currencySymbol
        )
        self.pnlAmount = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .precision,
            sign: .always,
        )
        self.pnlColor = pnl >= 0 ? .rising : .falling
        self.actions = [.close, .share]
        self.displaySymbol = position.displaySymbol
        self.orderValueInToken = if let orderValueInToken {
            CurrencyFormatter.localizedString(
                from: orderValueInToken,
                format: .precision,
                sign: .never,
                symbol: .custom(position.tokenSymbol)
            )
        } else {
            ""
        }
        self.orderValueInFiatMoney = if let orderValueInUSD {
            CurrencyFormatter.localizedString(
                from: orderValueInUSD * Currency.current.decimalRate,
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            ""
        }
        self.entryPrice = if let decimalEntryPrice {
            CurrencyFormatter.localizedString(
                from: decimalEntryPrice * Currency.current.decimalRate,
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            position.entryPrice
        }
        self.date = if let date = DateFormatter.iso8601Full.date(from: position.createdAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            position.createdAt
        }
        
        self.liquidationPrice = if let decimalEntryPrice {
            PerpetualChangeSimulation.liquidationPrice(
                side: side,
                entryPrice: decimalEntryPrice,
                leverageMultiplier: Decimal(position.leverage)
            )
        } else {
            nil
        }
        self.closePrice = nil
        self.closedAt = nil
    }
    
    init(wallet: Wallet, history: PerpetualPositionHistoryItem) {
        let side = PerpetualOrderSide(rawValue: history.side) ?? .short
        let decimalQuantity = Decimal(string: history.quantity, locale: .enUSPOSIX)
        let decimalEntryPrice = Decimal(string: history.entryPrice, locale: .enUSPOSIX)
        let decimalClosePrice = Decimal(string: history.closePrice, locale: .enUSPOSIX)
        let pnl = Decimal(string: history.realizedPnL, locale: .enUSPOSIX) ?? 0
        let multiplier = PerpetualLeverage.stringRepresentation(multiplier: history.leverage)
        
        self.wallet = wallet
        self.positionID = history.positionID
        self.state = .closed
        self.side = side
        self.iconURL = history.iconURL
        switch PerpetualOrderSide(rawValue: history.side) {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(history.tokenSymbol)
            self.leverage = .long(multiplier)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(history.tokenSymbol)
            self.leverage = .short(multiplier)
        default:
            self.directionWithSymbol = "\(history.side) \(history.tokenSymbol)"
            self.leverage = .short(multiplier)
        }
        self.pnl = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .precision,
            sign: .always,
            symbol: .currencySymbol
        )
        self.pnlAmount = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .precision,
            sign: .always,
        )
        self.pnlColor = pnl >= 0 ? .rising : .falling
        self.actions = [.tradeAgain, .share]
        self.displaySymbol = history.displaySymbol
        if let decimalQuantity {
            self.orderValueInToken = CurrencyFormatter.localizedString(
                from: decimalQuantity,
                format: .precision,
                sign: .never,
                symbol: .custom(history.tokenSymbol)
            )
        } else {
            self.orderValueInToken = "-"
        }
        if let decimalQuantity, let decimalEntryPrice {
            self.orderValueInFiatMoney = CurrencyFormatter.localizedString(
                from: decimalQuantity * decimalEntryPrice * Currency.current.decimalRate,
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            self.orderValueInFiatMoney = "-"
        }
        self.entryPrice = if let decimalEntryPrice {
            CurrencyFormatter.localizedString(
                from: decimalEntryPrice * Currency.current.decimalRate,
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            history.entryPrice
        }
        self.date = if let date = DateFormatter.iso8601Full.date(from: history.closedAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            history.closedAt
        }
        
        self.liquidationPrice = nil
        self.closePrice = if let decimalClosePrice {
            CurrencyFormatter.localizedString(
                from: decimalClosePrice * Currency.current.decimalRate,
                format: .precision,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            history.closePrice
        }
        self.closedAt = history.closedAt
    }
    
}
