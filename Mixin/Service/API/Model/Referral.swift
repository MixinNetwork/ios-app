import Foundation

struct Referral: Decodable {
    
    struct Code: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case code = "code"
            case inviterPercent = "inviter_percent"
            case isDefault = "is_default"
        }
        
        let code: String
        let inviterPercent: String
        let isDefault: Bool
        
    }
    
    enum CodingKeys: String, CodingKey {
        case codes = "codes"
        case tradingCommissionRatio = "trading_commission_ratio"
        case membershipLevel = "membership_level"
        case expiredAt = "expired_at"
        case hasBeenInvited = "has_been_invited"
    }
    
    let codes: [Code]
    let tradingCommissionRatio: String
    let membershipLevel: String
    let expiredAt: String
    let hasBeenInvited: Bool
    
}
