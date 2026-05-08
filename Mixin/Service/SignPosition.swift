import Foundation

enum SignPosition {
    case left
    case right
}

extension SignPosition {
    
    static let percentage: SignPosition = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = .current
        let format = formatter.positiveFormat ?? ""
        return format.first == "%" ? .left : .right
    }()
    
    static let currency: SignPosition = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        let format = formatter.positiveFormat ?? ""
        return format.last == "¤" ? .right : .left
    }()
    
}
