import Foundation
import MixinServices

struct SwapQuote {
    
    enum PriceUnit {
        case send
        case receive
    }
    
    let sendToken: TokenItem
    let sendAmount: Decimal
    let receiveToken: SwappableToken
    let receiveAmount: Decimal
    
    func updated(receiveAmount: Decimal) -> SwapQuote {
        SwapQuote(sendToken: self.sendToken,
                  sendAmount: self.sendAmount,
                  receiveToken: self.receiveToken,
                  receiveAmount: receiveAmount)
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

extension SwapQuote: CustomStringConvertible {
    
    var description: String {
        "<SwapQuote \(sendAmount)\(sendToken.symbol) -> \(receiveAmount)\(receiveToken.symbol)>"
    }
    
}
