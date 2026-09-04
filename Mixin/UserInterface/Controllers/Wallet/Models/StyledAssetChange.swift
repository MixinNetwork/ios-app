import Foundation
import MixinServices

struct StyledAssetChange {
    
    enum AmountStyle {
        case incoming
        case outgoing
        case plain
        case gray
    }
    
    let token: any Token
    let amount: String
    let amountStyle: AmountStyle
    
}
