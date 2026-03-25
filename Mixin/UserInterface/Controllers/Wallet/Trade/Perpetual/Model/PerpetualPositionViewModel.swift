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
    let type: PerpetualPositionType
    let side: PerpetualOrderSide
    let iconURL: URL?
    let directionWithSymbol: String
    let leverageMultiplier: String
    let pnl: String
    let pnlColor: MarketColor
    let roe: String?
    let pnlWithROE: String
    let actions: [Action]
    let displaySymbol: String?
    let quantity: String
    let tokenSymbol: String?
    let orderValueInToken: String
    let entryPrice: String
    let date: String
    
    // Only available for open positions
    let state: PerpetualPosition.State?
    let margin: String?
    let estimatedReceiving: EstimatedReceiving?
    let liquidationPrice: String?
    
    // Only available for closed positions
    let closePrice: String?
    let closedAt: String?
    
    init(wallet: Wallet, position: PerpetualPositionItem) {
        let pnl = Decimal(string: position.unrealizedPnL, locale: .enUSPOSIX) ?? 0
        let entryPrice = Decimal(string: position.entryPrice, locale: .enUSPOSIX)
        let quantity = abs(Decimal(string: position.quantity, locale: .enUSPOSIX) ?? 0)
        let multiplier = PerpetualLeverage.stringRepresentation(multiplier: position.leverage)
        let side = PerpetualOrderSide(rawValue: position.side) ?? .short
        let margin = Decimal(string: position.margin, locale: .enUSPOSIX)
        let localizedPnL = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .fiatMoneyValue,
            sign: .always,
            symbol: .currencySymbol
        )
        
        self.wallet = wallet
        self.marketID = position.marketID
        self.positionID = position.positionID
        self.type = .open
        self.side = side
        self.iconURL = position.iconURL
        switch side {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(position.tokenSymbol)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(position.tokenSymbol)
        }
        self.leverageMultiplier = multiplier
        self.pnl = localizedPnL
        self.pnlColor = pnl >= 0 ? .rising : .falling
        if let margin, margin != 0 {
            let roe = PercentageFormatter.string(
                from: pnl / margin,
                format: .pretty,
                sign: .always,
                options: .keepOneFractionDigitForZero
            )
            self.roe = roe
            self.pnlWithROE = localizedPnL + " (" + roe + ")"
        } else {
            self.roe = nil
            self.pnlWithROE = localizedPnL
        }
        self.actions = [.close, .share]
        self.displaySymbol = position.displaySymbol
        self.quantity = CurrencyFormatter.localizedString(
            from: quantity,
            format: .precision,
            sign: .never,
        )
        self.tokenSymbol = position.tokenSymbol
        self.orderValueInToken = CurrencyFormatter.localizedString(
            from: quantity,
            format: .precision,
            sign: .never,
            symbol: .custom(position.tokenSymbol)
        )
        self.entryPrice = if let entryPrice {
            CurrencyFormatter.localizedString(
                from: entryPrice * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
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
        
        self.state = position.state.knownCase
        self.margin = if let margin {
            CurrencyFormatter.localizedString(
                from: margin * Currency.current.decimalRate,
                format: .fiatMoneyValue,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            nil
        }
        self.estimatedReceiving = if let margin {
            EstimatedReceiving(
                assetID: position.settleAssetID,
                receivingAmount: margin + pnl,
                pnlAmount: pnl
            )
        } else {
            nil
        }
        self.liquidationPrice = if let entryPrice {
            PerpetualChangeSimulation.liquidationPrice(
                side: side,
                entryPrice: entryPrice,
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
        let quantity = abs(Decimal(string: history.quantity, locale: .enUSPOSIX) ?? 0)
        let entryPrice = Decimal(string: history.entryPrice, locale: .enUSPOSIX)
        let closePrice = Decimal(string: history.closePrice, locale: .enUSPOSIX)
        let pnl = Decimal(string: history.realizedPnL, locale: .enUSPOSIX) ?? 0
        let leverage = PerpetualLeverage.stringRepresentation(multiplier: history.leverage)
        let localizedPnL = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .fiatMoneyValue,
            sign: .always,
            symbol: .currencySymbol
        )
        
        self.wallet = wallet
        self.marketID = history.marketID
        self.positionID = history.positionID
        self.type = .closed
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
        self.leverageMultiplier = leverage
        self.pnl = localizedPnL
        self.pnlColor = pnl >= 0 ? .rising : .falling
        if let entryPrice, let closePrice {
            var roe = (closePrice / entryPrice - 1) * Decimal(history.leverage)
            roe = abs(roe)
            if pnl < 0 {
                roe = -roe
            }
            let localizedROE = PercentageFormatter.string(
                from: roe,
                format: .pretty,
                sign: .always,
                options: .keepOneFractionDigitForZero
            )
            self.roe = localizedROE
            self.pnlWithROE = localizedPnL + " (" + localizedROE + ")"
        } else {
            self.roe = nil
            self.pnlWithROE = localizedPnL
        }
        self.actions = [.tradeAgain, .share]
        self.displaySymbol = history.displaySymbol
        self.quantity = CurrencyFormatter.localizedString(
            from: quantity,
            format: .precision,
            sign: .never,
        )
        self.tokenSymbol = history.tokenSymbol
        self.orderValueInToken = CurrencyFormatter.localizedString(
            from: quantity,
            format: .precision,
            sign: .never,
            symbol: .custom(history.tokenSymbol)
        )
        self.entryPrice = if let entryPrice {
            CurrencyFormatter.localizedString(
                from: entryPrice * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
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
        
        self.state = nil
        self.margin = nil
        self.estimatedReceiving = nil
        self.liquidationPrice = nil
        self.closePrice = if let closePrice {
            CurrencyFormatter.localizedString(
                from: closePrice * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            history.closePrice
        }
        self.closedAt = history.closedAt
    }
    
}
