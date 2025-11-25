import Foundation
import MixinServices

enum ExchangeRateQuote {
    
    // Terms:
    // 1 XIN = 150 USDT - Exchange rate quote
    // XIN - Numeraire
    // USDT - Quote currency
    
    enum Numeraire {
        
        case send
        case receive
        
        mutating func toggle() {
            switch self {
            case .send:
                self = .receive
            case .receive:
                self = .send
            }
        }
        
    }
    
    static func expression(
        sendAmount: Decimal,
        sendSymbol: String,
        receiveAmount: Decimal,
        receiveSymbol: String,
        numeraire: Numeraire
    ) -> String {
        switch numeraire {
        case .send:
            let quote = CurrencyFormatter.localizedString(
                from: receiveAmount / sendAmount,
                format: .precision,
                sign: .never
            )
            return "1 \(sendSymbol) ≈ \(quote) \(receiveSymbol)"
        case .receive:
            let quote = CurrencyFormatter.localizedString(
                from: sendAmount / receiveAmount,
                format: .precision,
                sign: .never
            )
            return "1 \(receiveSymbol) ≈ \(quote) \(sendSymbol)"
        }
    }
    
}
