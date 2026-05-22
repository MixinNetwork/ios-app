import Foundation
import MixinServices

struct PerpetualPositionViewModel {
    
    struct EstimatedReceiving {
        let assetID: String
        let receivingAmount: Decimal
        let pnlAmount: Decimal
    }
    
    let wallet: Wallet
    let marketID: String
    let positionID: String
    let side: PerpetualOrderSide
    let iconURL: URL?
    let directionWithSymbol: String
    let leverageMultiplier: Int
    let leverage: String
    let pnl: String
    let pnlColor: MarketColor
    let roeWithSign: String?
    let roeWithoutSign: String?
    let pnlWithROE: String
    let displaySymbol: String?
    let decimalQuantity: Decimal
    let quantity: String
    let tokenSymbol: String?
    let orderValueInToken: String
    let entryPrice: String
    let date: String
    let priceFormatStyle: Decimal.FormatStyle.Currency
    let state: PerpetualPosition.State?
    let decimalMargin: Decimal?
    let margin: String?
    let estimatedReceiving: EstimatedReceiving?
    let liquidationPrice: String?
    let takeProfitPrice: Decimal?
    let stopLossPrice: Decimal?
    let orderValueInFiatMoney: String?
    
    init(wallet: Wallet, position: PerpetualPositionItem) {
        let pnl = Decimal(string: position.unrealizedPnL, locale: .enUSPOSIX) ?? 0
        let entryPrice = Decimal(string: position.entryPrice, locale: .enUSPOSIX)
        let decimalQuantity = abs(Decimal(string: position.quantity, locale: .enUSPOSIX) ?? 0)
        let leverage = PerpetualLeverage.stringRepresentation(multiplier: position.leverage)
        let side = PerpetualOrderSide(rawValue: position.side) ?? .short
        let margin = Decimal(string: position.margin, locale: .enUSPOSIX)
        let roe = Decimal(string: position.roe, locale: .enUSPOSIX)
        let localizedPnL = CurrencyFormatter.localizedString(
            from: pnl * Currency.current.decimalRate,
            format: .fiatMoneyPretty,
            sign: .always,
            symbol: .currencySymbol
        )
        
        self.wallet = wallet
        self.marketID = position.marketID
        self.positionID = position.positionID
        self.side = side
        self.iconURL = position.iconURL
        switch side {
        case .long:
            self.directionWithSymbol = R.string.localizable.long_asset(position.tokenSymbol)
        case .short:
            self.directionWithSymbol = R.string.localizable.short_asset(position.tokenSymbol)
        }
        self.leverageMultiplier = position.leverage
        self.leverage = leverage
        self.pnl = localizedPnL
        self.pnlColor = pnl >= 0 ? .rising : .falling
        if let margin, margin != 0 {
            let roe = roe ?? max(-1, pnl / margin)
            let roeWithSign = PercentageFormatter.string(
                from: roe,
                format: .pretty,
                sign: .always,
                options: .keepOneFractionDigitForZero
            )
            let roeWithoutSign = PercentageFormatter.string(
                from: roe,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero
            )
            self.roeWithSign = roeWithSign
            self.roeWithoutSign = roeWithoutSign
            self.pnlWithROE = localizedPnL + " (" + roeWithoutSign + ")"
            self.orderValueInFiatMoney = CurrencyFormatter.localizedString(
                from: margin * Decimal(position.leverage) * Currency.current.decimalRate,
                format: .fiatMoneyPretty,
                sign: .never,
                symbol: .currencySymbol,
            )
        } else {
            self.roeWithSign = nil
            self.roeWithoutSign = nil
            self.pnlWithROE = localizedPnL
            self.orderValueInFiatMoney = nil
        }
        self.displaySymbol = position.displaySymbol
        self.decimalQuantity = decimalQuantity
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
        self.entryPrice = if let entryPrice {
            entryPrice.formatted(position.priceFormatStyle)
        } else {
            position.entryPrice
        }
        self.date = if let date = DateFormatter.iso8601Full.date(from: position.createdAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            position.createdAt
        }
        self.priceFormatStyle = position.priceFormatStyle
        
        self.state = position.state.knownCase
        self.decimalMargin = margin
        self.margin = if let margin {
            CurrencyFormatter.localizedString(
                from: margin * Currency.current.decimalRate,
                format: .fiatMoneyPretty,
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
        if let price = position.liquidationPrice,
           !price.isEmpty,
           let decimalPrice = Decimal(string: price, locale: .enUSPOSIX)
        {
            self.liquidationPrice = decimalPrice.formatted(position.priceFormatStyle)
        } else {
            self.liquidationPrice = nil
        }
        self.takeProfitPrice = if let price = position.takeProfitPrice, !price.isEmpty {
            Decimal(string: price, locale: .enUSPOSIX)
        } else {
            nil
        }
        self.stopLossPrice = if let price = position.stopLossPrice, !price.isEmpty {
            Decimal(string: price, locale: .enUSPOSIX)
        } else {
            nil
        }
    }
    
}
