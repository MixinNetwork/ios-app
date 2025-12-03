import Foundation
import MixinServices

struct StyledAssetChange {
    
    enum AmountStyle {
        case income
        case outcome
        case plain
        case gray
    }
    
    let token: any Token
    let amount: String
    let amountStyle: AmountStyle
    
}
