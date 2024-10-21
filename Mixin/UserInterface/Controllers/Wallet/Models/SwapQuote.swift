import Foundation
import MixinServices

final class SwapQuote: SwapQuoteDraft {
    
    let receiveAmount: Decimal
    let source: RouteTokenSource
    let payload: String
    
    override var description: String {
        "<SwapQuote \(sendAmount)\(sendToken.symbol) -> \(receiveAmount)\(receiveToken.symbol)>"
    }
    
    init(
        sendToken: TokenItem, sendAmount: Decimal, receiveToken: SwappableToken,
        receiveAmount: Decimal, source: RouteTokenSource, payload: String
    ) {
        self.receiveAmount = receiveAmount
        self.source = source
        self.payload = payload
        super.init(sendToken: sendToken, sendAmount: sendAmount, receiveToken: receiveToken)
    }
    
    init(draft: SwapQuoteDraft, receiveAmount: Decimal, source: RouteTokenSource, payload: String) {
        self.receiveAmount = receiveAmount
        self.source = source
        self.payload = payload
        super.init(
            sendToken: draft.sendToken,
            sendAmount: draft.sendAmount,
            receiveToken: draft.receiveToken
        )
    }
    
}

extension SwapQuote {
    
    enum PriceUnit {
        case send
        case receive
    }
    
    static func priceRepresentation(
        sendToken: TokenItem,
        sendAmount: Decimal,
        receiveToken: SwappableToken,
        receiveAmount: Decimal,
        unit: PriceUnit
    ) -> String {
        switch unit {
        case .send:
            let price = CurrencyFormatter.localizedString(
                from: receiveAmount / sendAmount,
                format: .precision,
                sign: .never
            )
            return "1 \(sendToken.symbol) ≈ \(price) \(receiveToken.symbol)"
        case .receive:
            let price = CurrencyFormatter.localizedString(
                from: sendAmount / receiveAmount,
                format: .precision,
                sign: .never
            )
            return "1 \(receiveToken.symbol) ≈ \(price) \(sendToken.symbol)"
        }
    }
    
    func priceRepresentation(unit: PriceUnit) -> String {
        Self.priceRepresentation(
            sendToken: sendToken,
            sendAmount: sendAmount,
            receiveToken: receiveToken,
            receiveAmount: receiveAmount,
            unit: unit
        )
    }
    
}
