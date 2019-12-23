import Foundation

public struct WithdrawalRequest: Codable {
    
    public let addressId: String
    public let amount: String
    public let traceId: String
    public var pin: String
    public let memo: String
    
    enum CodingKeys: String, CodingKey {
        case addressId = "address_id"
        case amount
        case traceId = "trace_id"
        case memo
        case pin
    }
    
    public init(addressId: String, amount: String, traceId: String, pin: String, memo: String) {
        self.addressId = addressId
        self.amount = amount
        self.traceId = traceId
        self.pin = pin
        self.memo = memo
    }
    
}
