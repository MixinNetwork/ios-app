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
        
        self.title = "Opened Position"
        self.wallet = wallet
        self.positionID = position.positionID
        self.iconURL = position.iconURL
        switch PerpetualOrderSide(rawValue: position.side) {
        case .long:
            self.directionWithSymbol = "Long \(position.symbol)"
            self.leverage = .long("\(position.leverage)x")
        case .short:
            self.directionWithSymbol = "Short \(position.symbol)"
            self.leverage = .short("\(position.leverage)x")
        default:
            self.directionWithSymbol = "\(position.side) \(position.symbol)"
            self.leverage = .short("\(position.leverage)x")
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
        self.entryPrice = position.entryPrice
        self.closePrice = nil
        self.date = position.createdAt
    }
    
    init(wallet: Wallet, history: PerpetualPositionHistoryItem) {
        let pnl = Decimal(string: history.realizedPnL, locale: .enUSPOSIX) ?? 0
        
        self.title = "Closed Position"
        self.wallet = wallet
        self.positionID = history.positionID
        self.iconURL = history.iconURL
        switch PerpetualOrderSide(rawValue: history.side) {
        case .long:
            self.directionWithSymbol = "Long \(history.symbol)"
            self.leverage = .long("\(history.leverage)x")
        case .short:
            self.directionWithSymbol = "Short \(history.symbol)"
            self.leverage = .short("\(history.leverage)x")
        default:
            self.directionWithSymbol = "\(history.side) \(history.symbol)"
            self.leverage = .short("\(history.leverage)x")
        }
        self.pnl = PnL(
            count: history.realizedPnL,
            symbol: history.symbol,
            isEarning: pnl >= 0
        )
        self.actions = [.tradeAgain, .share]
        self.product = history.product
        self.orderValueInToken = "Under Construction"
        self.orderValueInFiatMoney = "Under Construction"
        self.entryPrice = history.entryPrice
        self.closePrice = history.closePrice
        self.date = history.closedAt
    }
    
}
