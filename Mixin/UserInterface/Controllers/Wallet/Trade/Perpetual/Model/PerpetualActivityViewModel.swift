import Foundation
import MixinServices

struct PerpetualActivityViewModel {
    
    struct PnL {
        let abbreviated: String
        let precised: String
        let percentage: String
        let receivingAmount: String
        let color: MarketColor
    }
    
    enum OrderType {
        case open(payAmount: String)
        case increase(payAmount: String)
        case close(pnl: PnL, closePrice: String)
    }
    
    enum Status {
        case normal
        case rejected
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
    let type: OrderType
    let status: Status
    let title: String
    let actions: [Action]
    let side: PerpetualOrderSide
    let iconURL: URL?
    let directionWithSymbol: String
    let leverageMultiplier: Int
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
        let decimalPayAmount = Decimal(string: order.payAmount, locale: .enUSPOSIX)
        let payAmount = decimalPayAmount?.formatted(order.priceFormatStyle)
        let side = PerpetualOrderSide(rawValue: order.side) ?? .short
        let quantity = abs(Decimal(string: order.quantity, locale: .enUSPOSIX) ?? 0)
        let entryPrice = Decimal(string: order.entryPrice, locale: .enUSPOSIX)
        let leverage = PerpetualLeverage.stringRepresentation(multiplier: order.leverage)
        
        self.wallet = wallet
        self.marketID = order.marketID
        self.positionID = order.positionID
        switch order.orderType.knownCase {
        case .open:
            self.type = .open(payAmount: payAmount ?? "")
            self.title = switch side {
            case .long:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.opened_long_failed()
                default:
                    R.string.localizable.opened_long()
                }
            case .short:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.opened_short_failed()
                default:
                    R.string.localizable.opened_short()
                }
            }
        case .increasePosition:
            self.type = .increase(payAmount: payAmount ?? "")
            self.title = switch side {
            case .long:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.added_long_failed()
                default:
                    R.string.localizable.added_long()
                }
            case .short:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.added_short_failed()
                default:
                    R.string.localizable.added_short()
                }
            }
        case .close:
            let decimalClosePrice = Decimal(string: order.closePrice, locale: .enUSPOSIX)
            let realizedPnL = Decimal(string: order.realizedPnL, locale: .enUSPOSIX) ?? 0
            let roe = Decimal(string: order.roe, locale: .enUSPOSIX) ?? 0
            let prettyPnL = CurrencyFormatter.localizedString(
                from: realizedPnL * Currency.current.decimalRate,
                format: .fiatMoneyPretty,
                sign: .always,
                symbol: .currencySymbol
            )
            let roeRepresentation = " (" + PercentageFormatter.string(
                from: roe,
                format: .pretty,
                sign: .never
            ) + ")"
            let pnl = PnL(
                abbreviated: prettyPnL + roeRepresentation,
                precised: CurrencyFormatter.localizedString(
                    from: realizedPnL * Currency.current.decimalRate,
                    format: .fiatMoneyPrecision,
                    sign: .always,
                    symbol: .currencySymbol
                ) + roeRepresentation,
                percentage: PercentageFormatter.string(
                    from: roe,
                    format: .pretty,
                    sign: .always,
                    options: .keepOneFractionDigitForZero
                ),
                receivingAmount: prettyPnL,
                color: realizedPnL >= 0 ? .rising : .falling
            )
            let localizedClosePrice = decimalClosePrice?.formatted(order.priceFormatStyle)
            self.type = .close(
                pnl: pnl,
                closePrice: localizedClosePrice ?? order.closePrice,
            )
            self.title = switch side {
            case .long:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.closed_long_failed()
                default:
                    R.string.localizable.closed_long()
                }
            case .short:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.closed_short_failed()
                default:
                    R.string.localizable.closed_short()
                }
            }
        default:
            assertionFailure("Unknown order type")
            return nil
        }
        switch order.status.knownCase {
        case .rejected:
            self.status = .rejected
            self.actions = []
        default:
            self.status = .normal
            switch order.orderType.knownCase {
            case .open, .increasePosition:
                self.actions = [.viewMarket, .share]
            case .close:
                self.actions = [.tradeAgain, .share]
            case .none:
                self.actions = []
            }
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
        self.leverageMultiplier = order.leverage
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
