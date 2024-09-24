import Foundation
import MixinServices

final class SwapQuote: SwapQuoteDraft {
    
    let receiveAmount: Decimal
    let source: RouteTokenSource
    
    override var description: String {
        "<SwapQuote \(sendAmount)\(sendToken.symbol) -> \(receiveAmount)\(receiveToken.symbol)>"
    }
    
    init(
        sendToken: TokenItem, sendAmount: Decimal, receiveToken: SwappableToken,
        receiveAmount: Decimal, source: RouteTokenSource
    ) {
        self.receiveAmount = receiveAmount
        self.source = source
        super.init(sendToken: sendToken, sendAmount: sendAmount, receiveToken: receiveToken)
    }
    
    init(draft: SwapQuoteDraft, receiveAmount: Decimal, source: RouteTokenSource) {
        self.receiveAmount = receiveAmount
        self.source = source
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
    
    func priceRepresentation(unit: PriceUnit) -> String {
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
    
}
