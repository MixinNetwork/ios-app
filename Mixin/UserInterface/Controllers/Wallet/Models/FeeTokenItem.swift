import Foundation
import MixinServices

final class FeeTokenItem {
    
    let amount: String
    let decimalAmount: Decimal
    let tokenItem: TokenItem
    
    init?(amount: String, tokenItem: TokenItem) {
        guard let decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) else {
            return nil
        }
        self.amount = amount
        self.decimalAmount = decimalAmount
        self.tokenItem = tokenItem
    }
    
}
