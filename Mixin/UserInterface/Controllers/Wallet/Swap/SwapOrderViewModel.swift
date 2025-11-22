import Foundation
import MixinServices

struct SwapOrderViewModel {
    
    struct AssetChange {
        let token: SwapOrder.Token?
        let amount: String
    }
    
    struct Filling {
        let percentage: String
        let amount: String
    }
    
    let orderID: String
    let wallet: Wallet
    let state: UnknownableEnum<SwapOrder.State>
    let type: UnknownableEnum<SwapOrder.OrderType>
    
    let payAssetID: String
    let payToken: SwapOrder.Token?
    let paySymbol: String
    let paying: AssetChange
    
    let receiveAssetID: String
    let receiveToken: SwapOrder.Token?
    let receiveSymbol: String
    let receivings: [AssetChange]
    
    let filling: Filling?
    
    let receivePrice: String?
    let sendPrice: String?
    let expiration: String?
    let createdAt: String
    let createdAtRepresentation: String
    
    var exchangingSymbolRepresentation: String {
        paySymbol + " → " + receiveSymbol
    }
    
    init(
        order: SwapOrder,
        wallet: Wallet,
        payToken: SwapOrder.Token?,
        receiveToken: SwapOrder.Token?,
    ) {
        let type = UnknownableEnum<SwapOrder.OrderType>(rawValue: order.orderType)
        let payAmount = Decimal(string: order.payAmount, locale: .enUSPOSIX) ?? 0
        let paySymbol = payToken?.symbol ?? "?"
        let receiveAmount: Decimal? = if let amount = order.receiveAmount {
            Decimal(string: amount, locale: .enUSPOSIX) ?? 0
        } else {
            nil
        }
        let receiveSymbol = receiveToken?.symbol ?? "?"
        
        self.orderID = order.orderID
        self.wallet = wallet
        self.state = .init(rawValue: order.state)
        self.type = type
        
        self.payAssetID = order.payAssetID
        self.payToken = payToken
        self.paySymbol = paySymbol
        self.paying = AssetChange(
            token: payToken,
            amount: CurrencyFormatter.localizedString(
                from: -payAmount,
                format: .precision,
                sign: .always,
                symbol: .custom(paySymbol)
            )
        )
        
        self.receiveAssetID = order.receiveAssetID
        self.receiveToken = receiveToken
        self.receiveSymbol = receiveSymbol
        
        switch type.knownCase {
        case .swap, .none:
            self.filling = nil
            if let receiveAmount {
                self.receivings = [AssetChange(
                    token: receiveToken,
                    amount: CurrencyFormatter.localizedString(
                        from: receiveAmount,
                        format: .precision,
                        sign: .always,
                        symbol: .custom(receiveSymbol)
                    )
                )]
                self.receivePrice = SwapQuote.priceRepresentation(
                    sendAmount: payAmount,
                    sendSymbol: paySymbol,
                    receiveAmount: receiveAmount,
                    receiveSymbol: receiveSymbol,
                    unit: .receive
                )
                self.sendPrice = SwapQuote.priceRepresentation(
                    sendAmount: payAmount,
                    sendSymbol: paySymbol,
                    receiveAmount: receiveAmount,
                    receiveSymbol: receiveSymbol,
                    unit: .send
                )
            } else {
                self.receivings = []
                self.receivePrice = nil
                self.sendPrice = nil
            }
        case .limit:
            guard
                let value = order.expectedReceiveAmount,
                let expectedReceiveAmount = Decimal(string: value, locale: .enUSPOSIX)
            else {
                self.receivings = []
                self.filling = nil
                self.receivePrice = nil
                self.sendPrice = nil
                break
            }
            
            let filledReceiveAmount: Decimal
            if let value = order.filledReceiveAmount {
                filledReceiveAmount = Decimal(string: value, locale: .enUSPOSIX) ?? 0
            } else {
                filledReceiveAmount = 0
            }
            
            switch state.knownCase {
            case .created, .pending, .failed, .cancelling, .cancelled, .expired, .none:
                self.receivings = [
                    AssetChange(
                        token: receiveToken,
                        amount: CurrencyFormatter.localizedString(
                            from: expectedReceiveAmount,
                            format: .precision,
                            sign: .always,
                            symbol: .custom(receiveSymbol)
                        )
                    )
                ]
            case .success:
                self.receivings = [
                    AssetChange(
                        token: receiveToken,
                        amount: CurrencyFormatter.localizedString(
                            from: filledReceiveAmount,
                            format: .precision,
                            sign: .always,
                            symbol: .custom(receiveSymbol)
                        )
                    )
                ]
            }
            
            let pendingAmount: Decimal = if let value = order.pendingAmount {
                Decimal(string: value, locale: .enUSPOSIX) ?? 0
            } else {
                0
            }
            let percent: Decimal = if payAmount == 0 {
                0
            } else {
                (payAmount - pendingAmount) / payAmount
            }
            let roundedPercent = NSDecimalNumber(decimal: percent)
                .rounding(accordingToBehavior: NSDecimalNumberHandler.extractIntegralPart)
                .decimalValue
            let percentage = NumberFormatter.percentage.string(decimal: roundedPercent) ?? ""
            let amount = CurrencyFormatter.localizedString(
                from: filledReceiveAmount,
                format: .precision,
                sign: .always,
                symbol: .custom(receiveSymbol)
            )
            self.filling = Filling(percentage: percentage, amount: amount)
            
            self.receivePrice = SwapQuote.priceRepresentation(
                sendAmount: payAmount,
                sendSymbol: paySymbol,
                receiveAmount: expectedReceiveAmount,
                receiveSymbol: receiveSymbol,
                unit: .receive
            )
            self.sendPrice = SwapQuote.priceRepresentation(
                sendAmount: payAmount,
                sendSymbol: paySymbol,
                receiveAmount: expectedReceiveAmount,
                receiveSymbol: receiveSymbol,
                unit: .send
            )
        }
        
        if let expiredAt = order.expiredAt, let date = DateFormatter.iso8601Full.date(from: expiredAt) {
            self.expiration = if date.timeIntervalSinceNow > 365 * .day {
                R.string.localizable.trade_expiry_never()
            } else {
                DateFormatter.dateFull.string(from: date)
            }
        } else {
            self.expiration = nil
        }
        self.createdAt = order.createdAt
        self.createdAtRepresentation = if let date = DateFormatter.iso8601Full.date(from: order.createdAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            order.createdAt
        }
    }
    
}

extension SwapOrderViewModel: Equatable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.orderID == rhs.orderID
    }
    
}
