import Foundation
import MixinServices

struct PerpetualOrderViewModel {
    
    struct PnL {
        let receivingAmount: String
        let percentage: String
        let aggregated: String
        let color: MarketColor
    }
    
    enum OrderType {
        case open(payAmount: String)
        case increasePosition(absolutePayAmount: String)
        case increaseMargin(absolutePayAmount: String)
        case decreaseMargin(absolutePayAmount: String)
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
    let order: PerpetualOrderItem
    let type: OrderType
    let status: Status
    let title: String
    let actions: [Action]
    let side: PerpetualOrderSide
    let directionWithSymbol: String
    let leverage: String
    let absoluteDecimalQuantity: Decimal
    let quantity: String
    let orderValueInToken: String
    let entryPrice: String
    let date: String
    let decimalPayAmount: Decimal
    let offset: String
    
    init?(wallet: Wallet, order: PerpetualOrderItem) {
        let decimalPayAmount = Decimal(string: order.payAmount, locale: .enUSPOSIX) ?? 0
        let payAmount = decimalPayAmount.formatted(
            Self.payAmountStyle.sign(strategy: .never)
        )
        let side = PerpetualOrderSide(rawValue: order.side) ?? .short
        let absoluteQuantity = abs(Decimal(string: order.quantity, locale: .enUSPOSIX) ?? 0)
        let entryPrice = Decimal(string: order.entryPrice, locale: .enUSPOSIX)
        let leverage = PerpetualLeverage.stringRepresentation(multiplier: order.leverage)
        
        self.wallet = wallet
        self.order = order
        switch order.orderType.knownCase {
        case .open:
            self.type = .open(payAmount: payAmount)
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
            self.type = .increasePosition(absolutePayAmount: payAmount)
            self.title = switch side {
            case .long:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.added_long_failed()
                default:
                    R.string.localizable.perps_added_position()
                }
            case .short:
                switch order.status.knownCase {
                case .rejected:
                    R.string.localizable.added_short_failed()
                default:
                    R.string.localizable.perps_added_position()
                }
            }
        case .increaseMargin:
            self.type = .increaseMargin(absolutePayAmount: payAmount)
            self.title = switch order.status.knownCase {
            case .rejected:
                R.string.localizable.perps_adding_margin_failed()
            default:
                R.string.localizable.perps_added_margin()
            }
        case .decreaseMargin:
            self.type = .decreaseMargin(absolutePayAmount: payAmount)
            self.title = switch order.status.knownCase {
            case .rejected:
                R.string.localizable.perps_reducing_margin_failed()
            default:
                R.string.localizable.perps_reduced_margin()
            }
        case .close:
            let decimalClosePrice = Decimal(string: order.closePrice, locale: .enUSPOSIX)
            let realizedPnL: Decimal
            let roe: Decimal
            if !order.netRealizedPnL.isEmpty,
               !order.netROE.isEmpty,
               let netRealizedPnL = Decimal(string: order.netRealizedPnL, locale: .enUSPOSIX),
               let netROE = Decimal(string: order.netROE, locale: .enUSPOSIX)
            {
                realizedPnL = netRealizedPnL
                roe = netROE
            } else {
                realizedPnL = Decimal(string: order.realizedPnL, locale: .enUSPOSIX) ?? 0
                roe = Decimal(string: order.roe, locale: .enUSPOSIX) ?? 0
            }
            let prettyPnL = CurrencyFormatter.localizedString(
                from: realizedPnL,
                format: .fiatMoneyPretty,
                sign: .always,
                symbol: .dollarSign
            )
            let pnl = PnL(
                receivingAmount: prettyPnL,
                percentage: PercentageFormatter.string(
                    from: roe,
                    format: .pretty,
                    sign: .always,
                    options: .keepOneFractionDigitForZero
                ),
                aggregated: prettyPnL + " (" + PercentageFormatter.string(
                    from: roe,
                    format: .pretty,
                    sign: .never
                ) + ")",
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
        case .none:
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
            case .open, .increasePosition, .increaseMargin, .decreaseMargin:
                self.actions = [.viewMarket]
            case .close:
                self.actions = [.tradeAgain, .share]
            case .none:
                self.actions = []
            }
        }
        self.side = side
        switch PerpetualOrderSide(rawValue: order.side) {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(order.tokenSymbol)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(order.tokenSymbol)
        default:
            self.directionWithSymbol = "\(order.side) \(order.tokenSymbol)"
        }
        self.leverage = leverage
        self.absoluteDecimalQuantity = absoluteQuantity
        self.quantity = CurrencyFormatter.localizedString(
            from: absoluteQuantity,
            format: .precision,
            sign: .never,
        )
        self.orderValueInToken = CurrencyFormatter.localizedString(
            from: absoluteQuantity,
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
        self.decimalPayAmount = decimalPayAmount
        self.offset = order.updatedAt
    }
    
}

extension PerpetualOrderViewModel {
    
    static var payAmountStyle: Decimal.FormatStyle.Currency {
        PerpetualMarket.userDisplayPriceFormatStyle(
            scale: Int(MixinToken.internalPrecision)
        )
    }
    
}
