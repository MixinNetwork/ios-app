import Foundation
import MixinServices

struct PerpetualPositionViewModel {
    
    struct PnL {
        let count: String
        let symbol: String
        let isEarning: Bool
    }
    
    enum Action {
        
        case tradeAgain
        case close
        case share
        
        func asPillAction() -> PillActionView.Action {
            switch self {
            case .tradeAgain:
                    .init(title: R.string.localizable.trade_again())
            case .close:
                    .init(title: "Close Position", style: .vibrant)
            case .share:
                    .init(title: R.string.localizable.share())
            }
        }
        
    }
    
    enum Leverage {
        case long(String)
        case short(String)
    }
    
    let title: String
    let wallet: Wallet
    let positionID: String
    let iconURL: URL?
    let directionWithSymbol: String
    let leverage: Leverage
    let pnl: PnL?
    let actions: [Action]
    let product: String?
    let orderValueInToken: String
    let orderValueInFiatMoney: String
    let entryPrice: String
    let closePrice: String?
    let date: String
    let closedAt: String?
    
    init(wallet: Wallet, position: PerpetualPositionItem) {
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
        
        self.title = "Opened Position"
        self.wallet = wallet
        self.positionID = position.positionID
        self.iconURL = position.iconURL
        switch PerpetualOrderSide(rawValue: position.side) {
        case .long:
            self.directionWithSymbol = "Long \(position.symbol)"
            self.leverage = .long(multiplier)
        case .short:
            self.directionWithSymbol = "Short \(position.symbol)"
            self.leverage = .short(multiplier)
        default:
            self.directionWithSymbol = "\(position.side) \(position.symbol)"
            self.leverage = .short(multiplier)
        }
        self.pnl = nil
        self.actions = [.close, .share]
        self.product = position.product
        self.orderValueInToken = if let orderValueInToken {
            CurrencyFormatter.localizedString(
                from: orderValueInToken,
                format: .precision,
                sign: .never,
                symbol: .custom(position.symbol)
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
        self.closePrice = nil
        self.date = if let date = DateFormatter.iso8601Full.date(from: position.createdAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            position.createdAt
        }
        self.closedAt = nil
    }
    
    init(wallet: Wallet, history: PerpetualPositionHistoryItem) {
        let pnl = Decimal(string: history.realizedPnL, locale: .enUSPOSIX) ?? 0
        let multiplier = PerpetualLeverage.stringRepresentation(multiplier: history.leverage)
        let decimalEntryPrice = Decimal(string: history.entryPrice, locale: .enUSPOSIX)
        let decimalClosePrice = Decimal(string: history.closePrice, locale: .enUSPOSIX)
        
        self.title = "Closed Position"
        self.wallet = wallet
        self.positionID = history.positionID
        self.iconURL = history.iconURL
        switch PerpetualOrderSide(rawValue: history.side) {
        case .long:
            self.directionWithSymbol = "Long \(history.symbol)"
            self.leverage = .long(multiplier)
        case .short:
            self.directionWithSymbol = "Short \(history.symbol)"
            self.leverage = .short(multiplier)
        default:
            self.directionWithSymbol = "\(history.side) \(history.symbol)"
            self.leverage = .short(multiplier)
        }
        self.pnl = PnL(
            count: CurrencyFormatter.localizedString(
                from: pnl,
                format: .precision,
                sign: .always
            ),
            symbol: "USDT",
            isEarning: pnl >= 0
        )
        self.actions = [.tradeAgain, .share]
        self.product = history.product
        self.orderValueInToken = "Under Construction"
        self.orderValueInFiatMoney = "Under Construction"
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
        self.date = if let date = DateFormatter.iso8601Full.date(from: history.closedAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            history.closedAt
        }
        self.closedAt = history.closedAt
    }
    
}
