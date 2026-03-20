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
    
    struct EstimatedReceiving {
        let assetID: String
        let receivingAmount: Decimal
        let pnlAmount: Decimal
    }
    
    let wallet: Wallet
    let marketID: String
    let positionID: String
    let state: PerpetualPositionType
    let side: PerpetualOrderSide
    let iconURL: URL?
    let directionWithSymbol: String
    let leverageMultiplier: String
    let pnl: String
    let pnlPercentage: Decimal?
    let pnlColor: MarketColor
    let actions: [Action]
    let displaySymbol: String?
    let quantity: String
    let tokenSymbol: String?
    let orderValueInToken: String
    let orderValueInFiatMoney: String
    let entryPrice: String
    let date: String
    
    // Only available for open positions
    let margin: String?
    let estimatedReceiving: EstimatedReceiving?
    let liquidationPrice: String?
    
    // Only available for closed positions
    let closePrice: String?
    let closedAt: String?
    
    init(wallet: Wallet, position: PerpetualPositionItem) {
        let pnl = Decimal(string: position.unrealizedPnL, locale: .enUSPOSIX) ?? 0
        let decimalEntryPrice = Decimal(string: position.entryPrice, locale: .enUSPOSIX)
        let decimalQuantity = abs(Decimal(string: position.quantity, locale: .enUSPOSIX) ?? 0)
        let multiplier = PerpetualLeverage.stringRepresentation(multiplier: position.leverage)
        let side = PerpetualOrderSide(rawValue: position.side) ?? .short
        let decimalMargin = Decimal(string: position.margin, locale: .enUSPOSIX)
        
        self.wallet = wallet
        self.marketID = position.marketID
        self.positionID = position.positionID
        self.state = .open
        self.side = side
        self.iconURL = position.iconURL
        switch side {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(position.tokenSymbol)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(position.tokenSymbol)
        }
        self.leverageMultiplier = multiplier
        self.pnl = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .precision,
            sign: .always,
            symbol: .currencySymbol
        )
        if let decimalEntryPrice {
            let entryValue = decimalQuantity * decimalEntryPrice
            let nowValue = entryValue + pnl
            self.pnlPercentage = nowValue / entryValue - 1
        } else {
            self.pnlPercentage = nil
        }
        self.pnlColor = pnl >= 0 ? .rising : .falling
        self.actions = [.close, .share]
        self.displaySymbol = position.displaySymbol
        self.quantity = CurrencyFormatter.localizedString(
            from: decimalQuantity,
            format: .precision,
            sign: .never,
        )
        self.tokenSymbol = position.tokenSymbol
        self.orderValueInToken = CurrencyFormatter.localizedString(
            from: decimalQuantity,
            format: .precision,
            sign: .never,
            symbol: .custom(position.tokenSymbol)
        )
        self.orderValueInFiatMoney = if let decimalEntryPrice {
            CurrencyFormatter.localizedString(
                from: decimalQuantity * decimalEntryPrice * Currency.current.decimalRate,
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
        
        self.margin = if let decimalMargin {
            CurrencyFormatter.localizedString(
                from: decimalMargin * Currency.current.decimalRate,
                format: .fiatMoney,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            nil
        }
        self.estimatedReceiving = if let decimalMargin {
            EstimatedReceiving(
                assetID: position.settleAssetID,
                receivingAmount: decimalMargin + pnl,
                pnlAmount: pnl
            )
        } else {
            nil
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
        let decimalQuantity = abs(Decimal(string: history.quantity, locale: .enUSPOSIX) ?? 0)
        let decimalEntryPrice = Decimal(string: history.entryPrice, locale: .enUSPOSIX)
        let decimalClosePrice = Decimal(string: history.closePrice, locale: .enUSPOSIX)
        let pnl = Decimal(string: history.realizedPnL, locale: .enUSPOSIX) ?? 0
        let multiplier = PerpetualLeverage.stringRepresentation(multiplier: history.leverage)
        
        self.wallet = wallet
        self.marketID = history.marketID
        self.positionID = history.positionID
        self.state = .closed
        self.side = side
        self.iconURL = history.iconURL
        switch PerpetualOrderSide(rawValue: history.side) {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(history.tokenSymbol)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(history.tokenSymbol)
        default:
            self.directionWithSymbol = "\(history.side) \(history.tokenSymbol)"
        }
        self.leverageMultiplier = multiplier
        self.pnl = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .precision,
            sign: .always,
            symbol: .currencySymbol
        )
        if let decimalEntryPrice {
            let entryValue = decimalQuantity * decimalEntryPrice
            let nowValue = entryValue + pnl
            self.pnlPercentage = nowValue / entryValue - 1
        } else {
            self.pnlPercentage = nil
        }
        self.pnlColor = pnl >= 0 ? .rising : .falling
        self.actions = [.tradeAgain, .share]
        self.displaySymbol = history.displaySymbol
        self.quantity = CurrencyFormatter.localizedString(
            from: decimalQuantity,
            format: .precision,
            sign: .never,
        )
        self.tokenSymbol = history.tokenSymbol
        self.orderValueInToken = CurrencyFormatter.localizedString(
            from: decimalQuantity,
            format: .precision,
            sign: .never,
            symbol: .custom(history.tokenSymbol)
        )
        if let decimalEntryPrice {
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
        
        self.margin = nil
        self.estimatedReceiving = nil
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
