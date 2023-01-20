import Foundation

public struct WithdrawalRequest: Codable {
    
    public let addressId: String
    public let amount: String
    public let traceId: String
    public var pin: String
    public let memo: String
    public let fee: String?
    public let assetId: String?
    public let destination: String?
    public let tag: String?
    
    enum CodingKeys: String, CodingKey {
        case addressId = "address_id"
        case amount
        case traceId = "trace_id"
        case memo
        case pin = "pin_base64"
        case fee
        case assetId = "asset_id"
        case destination
        case tag
    }
    
    public init(addressId: String, amount: String, traceId: String, pin: String, memo: String, fee: String?, assetId: String?, destination: String?, tag: String?) {
        self.addressId = addressId
        self.amount = AmountFormatter.formattedAmount(amount)
        self.traceId = traceId
        self.pin = pin
        self.memo = memo
        self.fee = fee
        self.assetId = assetId
        self.destination = destination
        self.tag = tag
    }
    
}
