import Foundation
import GRDB

public struct MembershipOrder {
    
    public struct FiatOrder: Codable {
        
        enum CodingKeys: String, CodingKey {
            case source
            case subscriptionID = "subscription_id"
        }
        
        public let source: String
        public let subscriptionID: String
        
    }
    
    public enum Category: String, Codable {
        case subscription = "SUB"
        case transaction = "TRANS"
    }
    
    public enum Status: String, Codable {
        case initial
        case paid
        case cancel
        case expired
        case failed
        case refund
    }
    
    public let orderID: UUID
    public let category: UnknownableEnum<Category>
    public let amount: String
    public let actualAmount: String
    public let originalAmount: String
    public let after: String
    public let before: String
    public let createdAt: String
    public let fiatOrder: FiatOrder?
    public let stars: Int
    public let paymentURL: String?
    public let status: UnknownableEnum<Status>
    
}

extension MembershipOrder: Codable {
    
    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case category
        case amount
        case actualAmount = "amount_actual"
        case originalAmount = "amount_original"
        case after
        case before
        case createdAt = "created_at"
        case fiatOrder = "fiat_order"
        case stars = "stars"
        case paymentURL = "payment_url"
        case status
    }
    
}

extension MembershipOrder: MixinFetchableRecord, MixinEncodableRecord, PersistableRecord {
    
    public static let databaseTableName = "membership_orders"
    
}
