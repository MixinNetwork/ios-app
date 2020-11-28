import Foundation

public struct FiatMoney: Decodable {
    
    public let code: String
    public let rate: DecimalNumber
    
}
