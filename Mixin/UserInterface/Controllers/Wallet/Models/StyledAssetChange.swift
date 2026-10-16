import Foundation
import MixinServices

struct StyledAssetChange {
    
    enum AmountStyle {
        case incoming
        case outgoing
        case primary
        case secondary
        case tertiary
    }
    
    let token: any Token
    let amount: String
    let amountStyle: AmountStyle
    
}
