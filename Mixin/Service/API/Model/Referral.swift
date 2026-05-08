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

extension Referral {
    
    struct RebatingCode {
        let code: String
        let rebate: Decimal
    }
    
    static func loadAvailableCode(completion: @escaping (RebatingCode?) -> Void) {
        RewardAPI.referral { result in
            switch result {
            case let .success(referral):
                let expiredAt = referral.expiredAt.toUTCDate()
                guard expiredAt.timeIntervalSinceNow > 0 else {
                    fallthrough
                }
                let defaultCode = referral.codes.first { code in
                    code.isDefault
                }
                guard let defaultCode else {
                    fallthrough
                }
                let inviterPercent = Decimal(
                    string: defaultCode.inviterPercent,
                    locale: .enUSPOSIX
                )
                let tradingCommissionRatio = Decimal(
                    string: referral.tradingCommissionRatio,
                    locale: .enUSPOSIX
                )
                let rebate = if let tradingCommissionRatio, let inviterPercent {
                    tradingCommissionRatio * max(0, 1 - inviterPercent)
                } else {
                    Decimal.zero
                }
                let availableCode = RebatingCode(
                    code: defaultCode.code,
                    rebate: rebate
                )
                completion(availableCode)
            case .failure:
                completion(nil)
            }
        }
    }
    
}
