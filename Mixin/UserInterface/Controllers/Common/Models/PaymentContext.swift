import Foundation

class PaymentContext {
    
    enum Category {
        case transfer(UserItem)
        case withdrawal(Address)
    }
    
    let category: Category
    let traceId = UUID().uuidString.lowercased()
    
    var asset: AssetItem!
    var amount = "0"
    var memo = ""
    
    init(category: Category, asset: AssetItem?) {
        self.category = category
        self.asset = asset
    }
    
}
