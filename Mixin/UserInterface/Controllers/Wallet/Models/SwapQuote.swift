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
        sendToken: BalancedSwapToken, sendAmount: Decimal, receiveToken: SwapToken,
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
        
        func toggled() -> PriceUnit {
            switch self {
            case .send:
                    .receive
            case .receive:
                    .send
            }
        }
        
    }
    
    static func priceRepresentation(
        sendAmount: Decimal,
        sendSymbol: String,
        receiveAmount: Decimal,
        receiveSymbol: String,
        unit: PriceUnit
    ) -> String {
        switch unit {
        case .send:
            let price = CurrencyFormatter.localizedString(
                from: receiveAmount / sendAmount,
                format: .precision,
                sign: .never
            )
            return "1 \(sendSymbol) ≈ \(price) \(receiveSymbol)"
        case .receive:
            let price = CurrencyFormatter.localizedString(
                from: sendAmount / receiveAmount,
                format: .precision,
                sign: .never
            )
            return "1 \(receiveSymbol) ≈ \(price) \(sendSymbol)"
        }
    }
    
    func priceRepresentation(unit: PriceUnit) -> String {
        Self.priceRepresentation(
            sendAmount: sendAmount,
            sendSymbol: sendToken.symbol,
            receiveAmount: receiveAmount,
            receiveSymbol: receiveToken.symbol,
            unit: unit
        )
    }
    
}
