import Foundation
import MixinServices

struct StyledAssetChange {
    
    enum AmountStyle {
        case income
        case outcome
        case plain
    }
    
    let token: any Token
    let amount: String
    let amountStyle: AmountStyle
    
}
