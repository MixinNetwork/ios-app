import Foundation

public struct MembershipOrder {
    
    public struct FiatOrder: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case source
            case subscriptionID = "subscription_id"
        }
        
        public let source: String
        public let subscriptionID: String
        
    }
    
    public enum Status: String, Decodable {
        case initial
        case paid
        case cancel
        case expired
        case failed
    }
    
    public let orderID: UUID
    public let after: UnknownableEnum<SafeMembership.Plan>
    public let before: UnknownableEnum<SafeMembership.Plan>
    public let createdAt: String
    public let fiatOrder: FiatOrder?
    public let source: String
    public let status: UnknownableEnum<Status>
    
}

extension MembershipOrder: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case after
        case before
        case createdAt = "created_at"
        case fiatOrder = "fiat_order"
        case source
        case status
    }
    
}

extension MembershipOrder {
    
    public enum Transition {
        case upgrade
        case renew
    }
    
    public var transition: Transition {
        switch (before.knownCase, after.knownCase) {
        case (.none, _), (.basic, .standard), (.standard, .premium):
                .upgrade
        default:
                .renew
        }
    }
    
}
