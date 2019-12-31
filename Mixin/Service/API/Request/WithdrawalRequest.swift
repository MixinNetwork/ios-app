import Foundation

struct WithdrawalRequest: Codable {
    
    let addressId: String
    let amount: String
    let traceId: String
    var pin: String
    let memo: String
    
    enum CodingKeys: String, CodingKey {
        case addressId = "address_id"
        case amount
        case traceId = "trace_id"
        case memo
        case pin
    }
    
    init(addressId: String, amount: String, traceId: String, pin: String, memo: String) {
        self.addressId = addressId
        self.amount = amount
        self.traceId = traceId
        self.pin = pin
        self.memo = memo
    }
    
}
