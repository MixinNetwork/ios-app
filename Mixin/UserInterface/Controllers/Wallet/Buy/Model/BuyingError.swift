import Foundation

enum BuyingError: Error {
    
    case noAvailableCurrency
    case noAvailableAsset
    case noAvailablePayment
    case invalidTokenFormat
    case paymentDeclined
    
}
